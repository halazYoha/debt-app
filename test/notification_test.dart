import 'package:flutter_test/flutter_test.dart';
import 'package:debt/core/notification_settings_provider.dart';
import 'package:debt/features/debt/domain/debtor.dart';

void main() {
  group('NotificationSettingsState Tests', () {
    test('default state has enabled=true and reminderDays=15', () {
      const state = NotificationSettingsState(enabled: true, reminderDays: 15);
      expect(state.enabled, isTrue);
      expect(state.reminderDays, equals(15));
    });

    test('copyWith updates fields correctly', () {
      const state = NotificationSettingsState(enabled: true, reminderDays: 15);
      final updated = state.copyWith(enabled: false, reminderDays: 30);
      expect(updated.enabled, isFalse);
      expect(updated.reminderDays, equals(30));
    });
  });

  group('Debtor Reminder Threshold Logic Tests', () {
    test('Debtor unpaid for >= 15 days triggers reminder threshold', () {
      final now = DateTime.now();
      final fifteenDaysAgo = now.subtract(const Duration(days: 15));

      final debtor = Debtor(
        id: '1',
        name: 'አበበ ቤከለ',
        phone: '0911223344',
        items: [
          DebtItem(
            name: 'ስኳር',
            quantity: 2,
            unit: 'ኪሎ',
            unitPrice: 100,
            date: fifteenDaysAgo,
          ),
        ],
        totalPaid: 0,
        borrowedDate: fifteenDaysAgo,
        lastTransactionDate: fifteenDaysAgo,
      );

      expect(debtor.remainingBalance, equals(200.0));
      expect(debtor.isFullyPaid, isFalse);

      final daysSinceLastPayment = now.difference(debtor.borrowedDate).inDays;
      expect(daysSinceLastPayment, greaterThanOrEqualTo(15));
    });

    test('Debtor with recent repayment does not exceed 15 days threshold', () {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final twoDaysAgo = now.subtract(const Duration(days: 2));

      final debtor = Debtor(
        id: '2',
        name: 'ካሳሁን',
        phone: '0911000000',
        items: [
          DebtItem(
            name: 'ዘይት',
            quantity: 1,
            unit: 'ሊትር',
            unitPrice: 500,
            date: thirtyDaysAgo,
          ),
        ],
        repayments: [
          RepaymentRecord(amount: 100, date: twoDaysAgo),
        ],
        totalPaid: 100,
        borrowedDate: thirtyDaysAgo,
        lastTransactionDate: twoDaysAgo,
      );

      final lastPaymentDate = debtor.repayments.last.date;
      final daysSinceLastPayment = now.difference(lastPaymentDate).inDays;

      expect(debtor.remainingBalance, equals(400.0));
      expect(daysSinceLastPayment, lessThan(15));
    });
  });
}
