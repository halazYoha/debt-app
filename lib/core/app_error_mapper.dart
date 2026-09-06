import 'package:firebase_auth/firebase_auth.dart';

class AppErrorMapper {
  /// Converts any exception into a user-friendly, localized Amharic error string.
  static String toAmharic(dynamic error) {
    if (error == null) return 'ስህተት ተከስቷል። እባክዎ ደግመው ይሞክሩ።';

    // 1. Handled Exception with string message (already localized or plain text)
    if (error is Exception) {
      final msg = error.toString().replaceAll('Exception: ', '').trim();
      if (_isAmharicText(msg)) {
        return msg;
      }
    }

    // 2. Firebase Auth Exceptions
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'የተሳሳተ ኢሜይል ወይም የይለፍ ቃል ያስገቡ።';
        case 'email-already-in-use':
          return 'ይህ ኢሜይል ቀደም ብሎ ተመዝግቧል። እባክዎ ይግቡ።';
        case 'weak-password':
          return 'የይለፍ ቃሉ በጣም አጭር ነው። ቢያንስ 6 ቁምፊዎች መሆን አለበት።';
        case 'invalid-email':
          return 'ትክክለኛ ኢሜይል አድራሻ ያስገቡ።';
        case 'user-disabled':
          return 'ይህ መለያ ታግዷል። እባክዎ ድጋፍ ያግኙ።';
        case 'too-many-requests':
          return 'ብዙ የተሳሳቱ ሙከራዎች አድርገዋል። ትንሽ ቆይተው ደግመው ይሞክሩ።';
        case 'network-request-failed':
          return 'የኢንተርኔት ግንኙነት የለም። ኔትወርክዎን ያረጋግጡ።';
        case 'operation-not-allowed':
          return 'ይህ አገልግሎት ለጊዜው አልተፈቀደም።';
        case 'requires-recent-login':
          return 'ለዚህ እርምጃ እንደገና መግባት አለብዎት።';
        default:
          break;
      }
    }

    // 3. Firebase Firestore Exceptions
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'ይህን እርምጃ ለመፈጸም ፈቃድ የለዎትም።';
        case 'unavailable':
          return 'ሰርቨሩ ለጊዜው አይሰራም። ኔትወርክዎን ወይም ትንሽ ቆይተው ደግመው ይሞክሩ።';
        case 'deadline-exceeded':
          return 'የኔትወርክ ጊዜ አልፏል። ኔትወርክዎን ያረጋግጡ።';
        case 'not-found':
          return 'የተፈለገው መዝገብ አልተገኘም።';
        case 'already-exists':
          return 'ይህ መዝገብ ቀደም ብሎ ተመዝግቧል።';
        case 'resource-exhausted':
          return 'የአገልግሎት መጠን አልፏል። ትንሽ ቆይተው ደግመው ይሞክሩ።';
        case 'unauthenticated':
          return 'እባክዎ መጀመሪያ ይግቡ።';
        default:
          break;
      }
    }

    // 4. String error processing
    final errorString = error.toString();
    if (errorString.contains('network-request-failed') ||
        errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup')) {
      return 'የኢንተርኔት ግንኙነት የለም። ኔትወርክዎን ያረጋግጡ።';
    }

    if (errorString.contains('user-not-found') ||
        errorString.contains('wrong-password') ||
        errorString.contains('invalid-credential')) {
      return 'የተሳሳተ ኢሜይል ወይም የይለፍ ቃል ያስገቡ።';
    }

    if (errorString.contains('email-already-in-use')) {
      return 'ይህ ኢሜይል ቀደም ብሎ ተመዝግቧል። እባክዎ ይግቡ።';
    }

    if (errorString.contains('weak-password')) {
      return 'የይለፍ ቃሉ በጣም አጭር ነው። ቢያንስ 6 ቁምፊዎች መሆን አለበት።';
    }

    if (errorString.contains('invalid-email')) {
      return 'ትክክለኛ ኢሜይል አድራሻ ያስገቡ።';
    }

    if (errorString.contains('permission-denied')) {
      return 'ይህን እርምጃ ለመፈጸም ፈቃድ የለዎትም።';
    }

    if (_isAmharicText(errorString)) {
      return errorString
          .replaceAll('Exception: ', '')
          .replaceAll(RegExp(r'^\[.*?\] '), '')
          .trim();
    }

    // Default fallback
    return 'ስህተት ተከስቷል። እባክዎ ደግመው ይሞክሩ።';
  }

  /// Checks if string contains Ethiopic / Amharic Unicode characters (\u1200-\u137F)
  static bool _isAmharicText(String text) {
    return RegExp(r'[\u1200-\u137F]').hasMatch(text);
  }
}
