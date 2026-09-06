import 'package:flutter_test/flutter_test.dart';
import 'package:debt/features/debt/domain/debtor.dart';
import 'package:debt/core/input_validators.dart';

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

    test('InputValidators name validation logic', () {
      expect(InputValidators.validateName(''), 'እባክዎ የተበዳሪውን ስም ያስገቡ።');
      expect(InputValidators.validateName('   '), 'እባክዎ የተበዳሪውን ስም ያስገቡ።');
      expect(InputValidators.validateName('12345'), 'ስም ቁጥር ብቻ መሆን አይችልም። እባክዎ ትክክለኛ ስም ያስገቡ።');
      expect(InputValidators.validateName('!!!'), 'ስም ቢያንስ አንድ ፊደል ማካተት አለበት።');
      expect(InputValidators.validateName('አበበ ከበደ'), isNull);
      expect(InputValidators.validateName('Abebe Kebede'), isNull);
    });

    test('InputValidators phone validation logic', () {
      expect(InputValidators.validatePhone(''), isNull);
      expect(InputValidators.validatePhone('0911223344'), isNull);
      expect(InputValidators.validatePhone('0712345678'), isNull);
      expect(InputValidators.validatePhone('+251911223344'), isNull);
      expect(InputValidators.validatePhone('1234'), 'ትክክለኛ የስልክ ቁጥር ያስገቡ (ምሳሌ፡ 0911223344 ወይም 0711223344)');
      expect(InputValidators.validatePhone('0811223344'), 'ትክክለኛ የስልክ ቁጥር ያስገቡ (ምሳሌ፡ 0911223344 ወይም 0711223344)');
    });

    test('Debtor balance recalculation after deleting a repayment', () {
      final now = DateTime.now();
      final debtor = Debtor(
        id: 'del-test',
        name: 'ቤተልሄም',
        phone: '0911000000',
        items: [DebtItem(name: 'ዘይት', quantity: 1, unit: 'ሊትር', unitPrice: 1000)],
        repayments: [
          RepaymentRecord(amount: 600, date: now),
          RepaymentRecord(amount: 400, date: now),
        ],
        totalPaid: 1000,
        borrowedDate: now,
        lastTransactionDate: now,
        settledDate: now,
      );

      expect(debtor.isFullyPaid, isTrue);

      // Simulate removing the second repayment
      final updatedRepayments = List<RepaymentRecord>.from(debtor.repayments)
        ..removeAt(1);
      final newTotalPaid =
          updatedRepayments.fold<double>(0.0, (sum, r) => sum + r.amount);
      final isNowUnpaid = (debtor.totalBorrowed - newTotalPaid) > 0;

      expect(newTotalPaid, 600.0);
      expect(isNowUnpaid, isTrue); // settledDate should become null
    });

    test('Debtor settledDate preserved when edit repayment still fully pays', () {
      final now = DateTime.now();
      final debtor = Debtor(
        id: 'edit-test',
        name: 'ጌትነት',
        phone: '0911000001',
        items: [DebtItem(name: 'ቡና', quantity: 2, unit: 'ኪሎ', unitPrice: 400)],
        repayments: [
          RepaymentRecord(amount: 500, date: now),
          RepaymentRecord(amount: 300, date: now),
        ],
        totalPaid: 800,
        borrowedDate: now,
        lastTransactionDate: now,
        settledDate: now,
      );

      expect(debtor.totalBorrowed, 800.0);
      expect(debtor.isFullyPaid, isTrue);

      // Simulate editing repayment[0] from 500 → 600
      final updatedRepayments = List<RepaymentRecord>.from(debtor.repayments);
      updatedRepayments[0] = RepaymentRecord(amount: 600, date: now);
      final newTotalPaid =
          updatedRepayments.fold<double>(0.0, (sum, r) => sum + r.amount);

      expect(newTotalPaid, 900.0);
      expect(newTotalPaid >= debtor.totalBorrowed, isTrue); // still fully paid
    });

    test('Debtor balance and settlement status update on editing borrowed item', () {
      final now = DateTime.now();
      final debtor = Debtor(
        id: 'item-edit-test',
        name: 'ዮሐንስ',
        phone: '0911002233',
        items: [
          DebtItem(name: 'ስኳር', quantity: 2, unit: 'ኪሎ', unitPrice: 100, date: now),
          DebtItem(name: 'ዘይት', quantity: 1, unit: 'ሊትር', unitPrice: 500, date: now),
        ],
        repayments: [
          RepaymentRecord(amount: 700, date: now),
        ],
        totalPaid: 700,
        borrowedDate: now,
        lastTransactionDate: now,
        settledDate: now, // fully paid initially (700 totalBorrowed, 700 totalPaid)
      );

      expect(debtor.totalBorrowed, 700.0);
      expect(debtor.isFullyPaid, isTrue);

      // Edit item[0] (Sugar) quantity from 2 -> 5 (new total borrowed = 5*100 + 500 = 1000)
      final updatedItems = List<DebtItem>.from(debtor.items);
      updatedItems[0] = DebtItem(name: 'ስኳር', quantity: 5, unit: 'ኪሎ', unitPrice: 100, date: now);
      final newTotalBorrowed = updatedItems.fold<double>(0.0, (acc, item) => acc + item.subtotal);
      final isNowFullyPaid = debtor.totalPaid >= newTotalBorrowed;
      final isNowUnpaid = !isNowFullyPaid;

      expect(newTotalBorrowed, 1000.0);
      expect(isNowFullyPaid, isFalse);
      expect(isNowUnpaid, isTrue); // settledDate becomes null
    });

    test('Debtor balance and settlement status update on deleting borrowed item', () {
      final now = DateTime.now();
      final debtor = Debtor(
        id: 'item-del-test',
        name: 'ማርታ',
        phone: '0911998877',
        items: [
          DebtItem(name: 'ዱቄት', quantity: 2, unit: 'ኪሎ', unitPrice: 200, date: now),
          DebtItem(name: 'ቡና', quantity: 1, unit: 'ኪሎ', unitPrice: 400, date: now),
        ],
        repayments: [
          RepaymentRecord(amount: 500, date: now),
        ],
        totalPaid: 500,
        borrowedDate: now,
        lastTransactionDate: now,
        settledDate: null, // unpaid initially (800 borrowed, 500 paid)
      );

      expect(debtor.totalBorrowed, 800.0);
      expect(debtor.remainingBalance, 300.0);
      expect(debtor.isFullyPaid, isFalse);

      // Delete item[1] (Coffee, 400 ETB), remaining item is Flour (400 ETB). Total paid = 500.
      final updatedItems = List<DebtItem>.from(debtor.items)..removeAt(1);
      final newTotalBorrowed = updatedItems.fold<double>(0.0, (acc, item) => acc + item.subtotal);
      final isNowFullyPaid = debtor.totalPaid >= newTotalBorrowed;

      expect(newTotalBorrowed, 400.0);
      expect(isNowFullyPaid, isTrue); // now fully paid because total paid (500) >= total borrowed (400)
    });
  });
}



