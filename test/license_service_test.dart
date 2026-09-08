import 'package:flutter_test/flutter_test.dart';
import 'package:debt/core/license/license_model.dart';
import 'package:debt/core/license/license_service.dart';

void main() {
  group('LicenseService Activation Code Generator Tests', () {
    test('Generates valid 8-character uppercase format for device ID', () {
      const deviceId = 'AND-9A8B7C6D';
      final code = LicenseService.generateCode(deviceId, LicensePlan.permanent);

      expect(code.length, equals(9)); // XXXX-XXXX (8 chars + 1 dash)
      expect(code, contains('-'));
      expect(code, equals(code.toUpperCase()));
    });

    test('Generates distinct codes for different plans on same device', () {
      const deviceId = 'AND-12345678';
      final codePermanent = LicenseService.generateCode(deviceId, LicensePlan.permanent);
      final codeAnnual = LicenseService.generateCode(deviceId, LicensePlan.annual);
      final codeMonthly = LicenseService.generateCode(deviceId, LicensePlan.monthly);

      expect(codePermanent, isNot(equals(codeAnnual)));
      expect(codeAnnual, isNot(equals(codeMonthly)));
      expect(codePermanent, isNot(equals(codeMonthly)));
    });

    test('Generates distinct codes for different device IDs', () {
      final code1 = LicenseService.generateCode('AND-11111111', LicensePlan.permanent);
      final code2 = LicenseService.generateCode('AND-22222222', LicensePlan.permanent);

      expect(code1, isNot(equals(code2)));
    });
  });
}
