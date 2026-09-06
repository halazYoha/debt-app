import 'package:firebase_auth/firebase_auth.dart';

class AppErrorMapper {
  static const String _networkErrorMessage =
      'የኢንተርኔት ግንኙነት የለም። ለመግባት እባክዎ የኢንተርኔት ግንኙነትዎን አበሩት/ያረጋግጡና ደግመው ይሞክሩ። 📶';

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
        case 'unavailable':
        case 'channel-error':
        case 'internal-error':
        case 'network-error':
        case 'unknown':
          return _networkErrorMessage;
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

    // 4. String / Exception lower-case pattern detection
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network-request-failed') ||
        errorString.contains('channel-error') ||
        errorString.contains('internal-error') ||
        errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('identitytoolkit') ||
        errorString.contains('connection failed') ||
        errorString.contains('connection refused') ||
        errorString.contains('network error') ||
        errorString.contains('offline') ||
        errorString.contains('unreachable') ||
        errorString.contains('timed out') ||
        errorString.contains('timeout') ||
        errorString.contains('xmlhttprequest') ||
        errorString.contains('getaddrinfo') ||
        errorString.contains('clientexception') ||
        errorString.contains('handshakeexception') ||
        errorString.contains('no address associated')) {
      return _networkErrorMessage;
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

    final rawText = error.toString();
    if (_isAmharicText(rawText)) {
      return rawText
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
