import 'package:cloud_firestore/cloud_firestore.dart';

enum LicensePlan { trial, monthly, annual, permanent }

class LicenseModel {
  final String deviceId;
  final String? userEmail;
  final DateTime installDate;
  final bool isActivated;
  final LicensePlan plan;
  final DateTime? activatedAt;
  final DateTime? expiryDate;
  final String? activationCode;

  const LicenseModel({
    required this.deviceId,
    this.userEmail,
    required this.installDate,
    required this.isActivated,
    this.plan = LicensePlan.trial,
    this.activatedAt,
    this.expiryDate,
    this.activationCode,
  });

  /// Calculate trial days remaining (30 days total)
  int get trialDaysRemaining {
    if (isActivated) return 0;
    final elapsed = DateTime.now().difference(installDate).inDays;
    final remaining = 30 - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// Calculate days remaining on paid plan (for monthly/annual)
  int? get planDaysRemaining {
    if (!isActivated || expiryDate == null) return null;
    final remaining = expiryDate!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Returns true if trial has expired AND the app is not activated, or if paid subscription has expired
  bool get isExpired {
    if (isActivated) {
      if (plan == LicensePlan.permanent) return false;
      if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) {
        return true;
      }
      return false;
    }
    // Check 30 day trial limit
    final elapsed = DateTime.now().difference(installDate).inDays;
    return elapsed >= 30;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'userEmail': userEmail,
      'installDate': Timestamp.fromDate(installDate),
      'isActivated': isActivated,
      'plan': plan.name,
      'activatedAt': activatedAt != null ? Timestamp.fromDate(activatedAt!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'activationCode': activationCode,
      'lastCheckedAt': FieldValue.serverTimestamp(),
    };
  }

  factory LicenseModel.fromFirestore(Map<String, dynamic> data, String fallbackDeviceId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final planStr = data['plan'] as String? ?? 'trial';
    LicensePlan parsedPlan = LicensePlan.trial;
    if (planStr == 'monthly') parsedPlan = LicensePlan.monthly;
    if (planStr == 'annual') parsedPlan = LicensePlan.annual;
    if (planStr == 'permanent') parsedPlan = LicensePlan.permanent;

    return LicenseModel(
      deviceId: data['deviceId'] as String? ?? fallbackDeviceId,
      userEmail: data['userEmail'] as String?,
      installDate: parseDate(data['installDate']),
      isActivated: data['isActivated'] as bool? ?? false,
      plan: parsedPlan,
      activatedAt: data['activatedAt'] != null ? parseDate(data['activatedAt']) : null,
      expiryDate: data['expiryDate'] != null ? parseDate(data['expiryDate']) : null,
      activationCode: data['activationCode'] as String?,
    );
  }

  LicenseModel copyWith({
    String? deviceId,
    String? userEmail,
    DateTime? installDate,
    bool? isActivated,
    LicensePlan? plan,
    DateTime? activatedAt,
    DateTime? expiryDate,
    String? activationCode,
  }) {
    return LicenseModel(
      deviceId: deviceId ?? this.deviceId,
      userEmail: userEmail ?? this.userEmail,
      installDate: installDate ?? this.installDate,
      isActivated: isActivated ?? this.isActivated,
      plan: plan ?? this.plan,
      activatedAt: activatedAt ?? this.activatedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      activationCode: activationCode ?? this.activationCode,
    );
  }
}
