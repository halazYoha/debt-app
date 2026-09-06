import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:debt/core/app_error_mapper.dart';

void main() {
  group('AppErrorMapper Tests', () {
    test('FirebaseAuthException mapping to Amharic', () {
      final wrongPasswordEx = FirebaseAuthException(
        code: 'wrong-password',
        message: 'The password is invalid',
      );
      expect(
        AppErrorMapper.toAmharic(wrongPasswordEx),
        'የተሳሳተ ኢሜይል ወይም የይለፍ ቃል ያስገቡ።',
      );

      final emailInUseEx = FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Email already exists',
      );
      expect(
        AppErrorMapper.toAmharic(emailInUseEx),
        'ይህ ኢሜይል ቀደም ብሎ ተመዝግቧል። እባክዎ ይግቡ።',
      );

      final weakPasswordEx = FirebaseAuthException(
        code: 'weak-password',
        message: 'Password should be at least 6 characters',
      );
      expect(
        AppErrorMapper.toAmharic(weakPasswordEx),
        'የይለፍ ቃሉ በጣም አጭር ነው። ቢያንስ 6 ቁምፊዎች መሆን አለበት።',
      );

      final networkEx = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'A network error has occurred',
      );
      expect(
        AppErrorMapper.toAmharic(networkEx),
        'የኢንተርኔት ግንኙነት የለም። ኔትወርክዎን ያረጋግጡ።',
      );
    });

    test('FirebaseException / Firestore mapping to Amharic', () {
      final permissionDeniedEx = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions',
      );
      expect(
        AppErrorMapper.toAmharic(permissionDeniedEx),
        'ይህን እርምጃ ለመፈጸም ፈቃድ የለዎትም።',
      );

      final unavailableEx = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'The service is unavailable',
      );
      expect(
        AppErrorMapper.toAmharic(unavailableEx),
        'ሰርቨሩ ለጊዜው አይሰራም። ኔትወርክዎን ወይም ትንሽ ቆይተው ደግመው ይሞክሩ።',
      );
    });

    test('String and Exception fallback mapping', () {
      final genericEx = Exception('Something bad happened in English');
      expect(
        AppErrorMapper.toAmharic(genericEx),
        'ስህተት ተከስቷል። እባክዎ ደግመው ይሞክሩ።',
      );

      final amharicEx = Exception('አዲስ ስህተት መልእክት');
      expect(
        AppErrorMapper.toAmharic(amharicEx),
        'አዲስ ስህተት መልእክት',
      );
    });
  });
}
