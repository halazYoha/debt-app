import 'package:flutter_test/flutter_test.dart';
import 'package:debt/features/debt/domain/debtor.dart';

void main() {
  group('Domain Model Tests', () {
    test('RepaymentRecord model serialization and deserialization', () {
      final now = DateTime.now();
      final record = RepaymentRecord(
        amount: 250.0,
        date: now,
        note: 'ከፊል ክፍያ',
      );

      expect(record.amount, 250.0);
      expect(record.note, 'ከፊል ክፍያ');
      expect(record.date, now);
    });

    test('DebtItem date property handling', () {
      final now = DateTime.now();
      final item = DebtItem(
        name: 'ቡና',
        quantity: 1,
        unit: 'ኪሎ',
        unitPrice: 350.0,
        date: now,
      );

      expect(item.name, 'ቡና');
      expect(item.date, now);

      final map = item.toMap();
      final restored = DebtItem.fromMap(map);
      expect(restored.name, 'ቡና');
      expect(restored.unitPrice, 350.0);
    });

    test('Debtor remaining balance calculation with repayments', () {
      final debtor = Debtor(
        id: '123',
        name: 'አበበ ብሩ',
        phone: '0911223344',
        items: [
          DebtItem(name: 'ስኳር', quantity: 2, unit: 'ኪሎ', unitPrice: 100, date: DateTime.now()),
        ],
        repayments: [
          RepaymentRecord(amount: 50, date: DateTime.now()),
        ],
        totalPaid: 50,
        borrowedDate: DateTime.now(),
        lastTransactionDate: DateTime.now(),
      );

      expect(debtor.totalBorrowed, 200.0);
      expect(debtor.remainingBalance, 150.0);
      expect(debtor.isFullyPaid, isFalse);
    });

    test('Debtor auto-delete warning and keepRecord logic', () {
      final now = DateTime.now();
      final settled26DaysAgo = now.subtract(const Duration(days: 26));
      final settled31DaysAgo = now.subtract(const Duration(days: 31));

      final warningDebtor = Debtor(
        id: '456',
        name: 'ካሳዬ',
        phone: '0912345678',
        items: [DebtItem(name: 'ዘይት', quantity: 1, unit: 'ሊትር', unitPrice: 500)],
        totalPaid: 500,
        borrowedDate: settled26DaysAgo,
        lastTransactionDate: settled26DaysAgo,
        settledDate: settled26DaysAgo,
        keepRecord: false,
      );

      expect(warningDebtor.isFullyPaid, isTrue);
      expect(warningDebtor.daysUntilDelete, 4);
      expect(warningDebtor.isWarningAutoDelete, isTrue);
      expect(warningDebtor.shouldAutoDelete, isFalse);

      final expiredDebtor = Debtor(
        id: '789',
        name: 'ተስፋዬ',
        phone: '0911000000',
        items: [DebtItem(name: 'ዱቄት', quantity: 1, unit: 'ኪሎ', unitPrice: 300)],
        totalPaid: 300,
        borrowedDate: settled31DaysAgo,
        lastTransactionDate: settled31DaysAgo,
        settledDate: settled31DaysAgo,
        keepRecord: false,
      );

      expect(expiredDebtor.shouldAutoDelete, isTrue);

      final protectedDebtor = Debtor(
        id: '789',
        name: 'ተስፋዬ',
        phone: '0911000000',
        items: [DebtItem(name: 'ዱቄት', quantity: 1, unit: 'ኪሎ', unitPrice: 300)],
        totalPaid: 300,
        borrowedDate: settled31DaysAgo,
        lastTransactionDate: settled31DaysAgo,
        settledDate: settled31DaysAgo,
        keepRecord: true,
      );

      expect(protectedDebtor.shouldAutoDelete, isFalse);
      expect(protectedDebtor.isWarningAutoDelete, isFalse);
      expect(protectedDebtor.daysUntilDelete, isNull);
    });
  });
}
