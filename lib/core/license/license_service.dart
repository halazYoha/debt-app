import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'license_model.dart';

class LicenseService {
  static const String secretKey = 'Htea2119';
  static const String devPhoneNumber = '0938236272';

  static const String _prefDeviceId = 'license_device_id';
  static const String _prefInstallDate = 'license_install_date';
  static const String _prefIsActivated = 'license_is_activated';
  static const String _prefPlan = 'license_plan';
  static const String _prefActivatedAt = 'license_activated_at';
  static const String _prefExpiryDate = 'license_expiry_date';
  static const String _prefActivationCode = 'license_activation_code';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate deterministic 8-character activation code for a given deviceId & plan
  static String generateCode(String deviceId, LicensePlan plan) {
    final cleanId = deviceId.trim().toUpperCase();
    final planStr = plan.name.toUpperCase(); // MONTHLY, ANNUAL, PERMANENT
    final payload = '$cleanId:$planStr';

    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(payload));
    final hex = digest.toString().toUpperCase();

    // Take 8 chars: 4 chars - 4 chars (e.g. A1B2-C3D4)
    final part1 = hex.substring(0, 4);
    final part2 = hex.substring(4, 8);
    return '$part1-$part2';
  }

  /// Get or initialize local Device ID and Install Date
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_prefDeviceId);

    if (id == null || id.isEmpty) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (kIsWeb) {
          final webInfo = await deviceInfo.webBrowserInfo;
          id = 'WEB-${webInfo.userAgent.hashCode.toRadixString(16)}';
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          id = 'AND-${androidInfo.id.toUpperCase()}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          id = 'IOS-${iosInfo.identifierForVendor?.toUpperCase() ?? 'UNKNOWN'}';
        } else {
          id = 'DEV-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
        }
      } catch (e) {
        id = 'APP-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}';
      }

      await prefs.setString(_prefDeviceId, id);
    }
    return id;
  }

  /// Helper to get user-specific storage key
  String _getUserKey(String deviceId, String? userEmail) {
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      return userEmail.trim().toLowerCase();
    }
    return deviceId;
  }

  /// Load current LicenseModel from local cache + Firestore sync
  Future<LicenseModel> loadLicenseStatus({String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    final userKey = _getUserKey(deviceId, userEmail);

    // Load local install date for this account or set to now
    String? installStr = prefs.getString('${_prefInstallDate}_$userKey');
    DateTime installDate;
    if (installStr == null) {
      installDate = DateTime.now();
      await prefs.setString('${_prefInstallDate}_$userKey', installDate.toIso8601String());
    } else {
      installDate = DateTime.tryParse(installStr) ?? DateTime.now();
    }

    final isActivated = prefs.getBool('${_prefIsActivated}_$userKey') ?? false;
    final planStr = prefs.getString('${_prefPlan}_$userKey') ?? 'trial';
    LicensePlan plan = LicensePlan.trial;
    if (planStr == 'monthly') plan = LicensePlan.monthly;
    if (planStr == 'annual') plan = LicensePlan.annual;
    if (planStr == 'permanent') plan = LicensePlan.permanent;

    final activatedAtStr = prefs.getString('${_prefActivatedAt}_$userKey');
    final activatedAt = activatedAtStr != null ? DateTime.tryParse(activatedAtStr) : null;

    final expiryDateStr = prefs.getString('${_prefExpiryDate}_$userKey');
    final expiryDate = expiryDateStr != null ? DateTime.tryParse(expiryDateStr) : null;

    final activationCode = prefs.getString('${_prefActivationCode}_$userKey');

    LicenseModel localModel = LicenseModel(
      deviceId: deviceId,
      userEmail: userEmail,
      installDate: installDate,
      isActivated: isActivated,
      plan: plan,
      activatedAt: activatedAt,
      expiryDate: expiryDate,
      activationCode: activationCode,
    );

    // Sync with Firestore doc for this specific user/email
    try {
      final docRef = _firestore.collection('app_customers').doc(userKey);
      final snapshot = await docRef.get(const GetOptions(source: Source.serverAndCache));
      
      bool foundActive = false;
      if (snapshot.exists && snapshot.data() != null) {
        final remoteModel = LicenseModel.fromFirestore(snapshot.data()!, deviceId);
        if (remoteModel.isActivated) {
          await _saveLocalLicense(remoteModel, userEmail: userEmail);
          localModel = remoteModel;
          foundActive = true;
        }
      }

      // If userKey doc is not activated, try fallback query by deviceId
      if (!foundActive) {
        final deviceQuery = await _firestore
            .collection('app_customers')
            .where('deviceId', isEqualTo: deviceId)
            .get();

        for (final doc in deviceQuery.docs) {
          if (doc.exists) {
            final remoteModel = LicenseModel.fromFirestore(doc.data(), deviceId);
            if (remoteModel.isActivated) {
              await _saveLocalLicense(remoteModel, userEmail: userEmail);
              localModel = remoteModel;
              foundActive = true;
              break;
            }
          }
        }
      }

      // If doc existed but was trial and no active doc found by deviceId, save doc data
      if (!foundActive && snapshot.exists && snapshot.data() != null) {
        final remoteModel = LicenseModel.fromFirestore(snapshot.data()!, deviceId);
        await _saveLocalLicense(remoteModel, userEmail: userEmail);
        localModel = remoteModel;
      }

      // Upsert current user registration into Firestore
      await docRef.set({
        ...localModel.toFirestore(),
        'userEmail': userEmail ?? localModel.userEmail,
        'deviceId': deviceId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore license sync note: $e');
    }

    return localModel;
  }

  /// Verify entered activation code (checks offline HMAC for monthly, annual, permanent)
  Future<bool> activateWithCode(String enteredCode, {String? userEmail}) async {
    final cleanCode = enteredCode.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
    if (cleanCode.length != 8) return false;

    final formattedEntered = '${cleanCode.substring(0, 4)}-${cleanCode.substring(4, 8)}';
    final deviceId = await getDeviceId();
    final userKey = _getUserKey(deviceId, userEmail);

    LicensePlan? matchedPlan;
    for (final plan in [LicensePlan.permanent, LicensePlan.annual, LicensePlan.monthly]) {
      // Check code matching deviceId or email
      final validCodeDevice = generateCode(deviceId, plan);
      final validCodeEmail = generateCode(userKey, plan);
      if (validCodeDevice == formattedEntered || validCodeEmail == formattedEntered) {
        matchedPlan = plan;
        break;
      }
    }

    if (matchedPlan == null) {
      // Also check Firestore in case admin set a custom code online for this user/device
      try {
        final doc = await _firestore.collection('app_customers').doc(userKey).get();
        if (doc.exists && doc.data() != null) {
          final remoteCode = (doc.data()?['activationCode'] as String?)
              ?.replaceAll('-', '')
              .replaceAll(' ', '')
              .toUpperCase();
          if (remoteCode == cleanCode) {
            final pStr = doc.data()?['plan'] as String? ?? 'permanent';
            if (pStr == 'monthly') {
              matchedPlan = LicensePlan.monthly;
            } else if (pStr == 'annual') {
              matchedPlan = LicensePlan.annual;
            } else {
              matchedPlan = LicensePlan.permanent;
            }
          }
        }
      } catch (_) {}
    }

    if (matchedPlan == null) return false;

    // Code matched! Calculate expiry
    final now = DateTime.now();
    DateTime? expiryDate;
    if (matchedPlan == LicensePlan.monthly) {
      expiryDate = now.add(const Duration(days: 30));
    } else if (matchedPlan == LicensePlan.annual) {
      expiryDate = now.add(const Duration(days: 365));
    } else {
      expiryDate = null; // Permanent
    }

    final updatedModel = LicenseModel(
      deviceId: deviceId,
      userEmail: userEmail,
      installDate: now,
      isActivated: true,
      plan: matchedPlan,
      activatedAt: now,
      expiryDate: expiryDate,
      activationCode: formattedEntered,
    );

    // Save locally for this account
    await _saveLocalLicense(updatedModel, userEmail: userEmail);

    // Sync to Firestore
    try {
      await _firestore
          .collection('app_customers')
          .doc(userKey)
          .set(updatedModel.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore update error after activation: $e');
    }

    return true;
  }

  Future<void> _saveLocalLicense(LicenseModel model, {String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    final userKey = _getUserKey(deviceId, userEmail ?? model.userEmail);

    await prefs.setBool('${_prefIsActivated}_$userKey', model.isActivated);
    await prefs.setString('${_prefPlan}_$userKey', model.plan.name);
    if (model.activatedAt != null) {
      await prefs.setString('${_prefActivatedAt}_$userKey', model.activatedAt!.toIso8601String());
    }
    if (model.expiryDate != null) {
      await prefs.setString('${_prefExpiryDate}_$userKey', model.expiryDate!.toIso8601String());
    } else {
      await prefs.remove('${_prefExpiryDate}_$userKey');
    }
    if (model.activationCode != null) {
      await prefs.setString('${_prefActivationCode}_$userKey', model.activationCode!);
    }
  }
}
