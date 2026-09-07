import 'package:cloud_firestore/cloud_firestore.dart';

/// A single line-item (product) taken on credit.
class DebtItem {
  final String name;      // e.g. "ስኳር" / "Sugar"
  final double quantity;  // e.g. 1
  final String unit;      // e.g. "kg" / "ኪሎ"
  final double unitPrice; // e.g. 100.0
  final DateTime? date;   // date when item/money was borrowed

  const DebtItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.date,
  });

  double get subtotal => quantity * unitPrice;

  factory DebtItem.fromMap(Map<String, dynamic> map) {
    return DebtItem(
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        if (date != null) 'date': Timestamp.fromDate(date!),
      };

  /// Human-readable row: "1 kg ስኳር × 100 = 100 ETB"
  String toDisplayString() =>
      '$quantity $unit $name × ${unitPrice.toStringAsFixed(0)} = ${subtotal.toStringAsFixed(0)} ETB';
}

/// A single repayment transaction record.
class RepaymentRecord {
  final String id;    // Firestore document ID in the repayments subcollection
  final double amount;
  final DateTime date;
  final String? note; // optional note, e.g. "ከፊል ክፍያ", "ሙሉ ዕዳ ተከፍሏል"
  final String? bankName; // bank used for transfer (creditor repayments only)

  const RepaymentRecord({
    this.id = '',
    required this.amount,
    required this.date,
    this.note,
    this.bankName,
  });

  factory RepaymentRecord.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return RepaymentRecord(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
      bankName: map['bankName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'date': Timestamp.fromDate(date),
        if (note != null && note!.isNotEmpty) 'note': note,
        if (bankName != null && bankName!.isNotEmpty) 'bankName': bankName,
      };
}

class Debtor {
  final String id;
  final String name;
  final String phone;           // optional — may be empty
  final List<DebtItem> items;   // structured item list
  final List<RepaymentRecord> repayments; // repayment transactions history
  final double totalPaid;
  final DateTime borrowedDate;
  final DateTime lastTransactionDate;
  final DateTime? settledDate;  // set when fully paid — used for auto-delete after 30 days
  final bool keepRecord;        // if true, record is protected from auto-deletion

  Debtor({
    required this.id,
    required this.name,
    required this.phone,
    required this.items,
    this.repayments = const [],
    required this.totalPaid,
    required this.borrowedDate,
    required this.lastTransactionDate,
    this.settledDate,
    this.keepRecord = false,
  });

  /// Total borrowed is derived from the item list
  double get totalBorrowed => items.fold(0.0, (acc, item) => acc + item.subtotal);

  double get remainingBalance => (totalBorrowed - totalPaid).clamp(0.0, double.infinity);
  bool get isFullyPaid => remainingBalance <= 0;

  /// Human-readable summary of items, e.g. "1 kg Sugar, 3 kg Coffee"
  String get itemsSummary => items.map((i) => '${i.quantity} ${i.unit} ${i.name}').join(', ');

  /// Days remaining until auto-delete (0 to 30), or null if not settled or protected
  int? get daysUntilDelete {
    if (!isFullyPaid || settledDate == null || keepRecord) return null;
    final daysSinceSettled = DateTime.now().difference(settledDate!).inDays;
    return (30 - daysSinceSettled).clamp(0, 30);
  }

  /// Whether this record is within 5 days of auto-deletion (settled 25 to 30 days ago)
  bool get isWarningAutoDelete {
    if (!isFullyPaid || settledDate == null || keepRecord) return false;
    final remaining = daysUntilDelete;
    return remaining != null && remaining <= 5 && remaining > 0;
  }

  /// Whether this record should be auto-removed (settled >= 30 days ago and not kept)
  bool get shouldAutoDelete {
    if (!isFullyPaid || settledDate == null || keepRecord) return false;
    final daysSinceSettled = DateTime.now().difference(settledDate!).inDays;
    return daysSinceSettled >= 30;
  }

  factory Debtor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse items list
    List<DebtItem> itemsList = [];
    final rawItems = data['items'];
    if (rawItems is List) {
      itemsList = rawItems
          .whereType<Map<String, dynamic>>()
          .map((m) => DebtItem.fromMap(m))
          .toList();
    } else {
      // Legacy: if no items list but itemsBorrowed string exists, create a
      // single item with the legacy totalBorrowed amount so old data still works.
      final legacyTotal = (data['totalBorrowed'] ?? 0).toDouble();
      final legacyDesc = (data['itemsBorrowed'] ?? '').toString();
      if (legacyTotal > 0) {
        itemsList = [
          DebtItem(
            name: legacyDesc.isNotEmpty ? legacyDesc : 'ዕቃ',
            quantity: 1,
            unit: '',
            unitPrice: legacyTotal,
          ),
        ];
      }
    }

    final double totalPaidVal = (data['totalPaid'] ?? 0).toDouble();
    final DateTime lastTxDate =
        (data['lastTransactionDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Parse repayments list — kept for backward compatibility with old documents
    // that still have repayments embedded as an array.
    // New repayments are stored in a subcollection and loaded separately.
    List<RepaymentRecord> repaymentsList = [];
    final rawRepayments = data['repayments'];
    // Only parse the array if it is a non-empty list.
    // An empty [] in Firestore is treated the same as a missing field —
    // we fall back to the synthetic record so totalPaid is always visible.
    if (rawRepayments is List && rawRepayments.isNotEmpty) {
      repaymentsList = rawRepayments
          .whereType<Map<String, dynamic>>()
          .map((m) => RepaymentRecord.fromMap(m))
          .toList();
    } else if (totalPaidVal > 0) {
      // Fallback: totalPaid is set but no repayment history exists.
      // Create a single synthetic record so the amount is visible.
      repaymentsList = [
        RepaymentRecord(
          amount: totalPaidVal,
          date: lastTxDate,
          note: 'የቀደመ ክፍያ',
        ),
      ];
    }

    return Debtor(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      items: itemsList,
      repayments: repaymentsList,
      totalPaid: totalPaidVal,
      borrowedDate: (data['borrowedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastTransactionDate: lastTxDate,
      settledDate: (data['settledDate'] as Timestamp?)?.toDate(),
      keepRecord: data['keepRecord'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'items': items.map((i) => i.toMap()).toList(),
      // NOTE: repayments are no longer stored inside the debtor document.
      // They live in the repayments subcollection to avoid the 1MB document limit.
      // The 'repayments' array in old documents is still read above for backward compatibility.
      'totalBorrowed': totalBorrowed, // denormalised for Firestore queries
      'totalPaid': totalPaid,
      'borrowedDate': Timestamp.fromDate(borrowedDate),
      'lastTransactionDate': Timestamp.fromDate(lastTransactionDate),
      if (settledDate != null) 'settledDate': Timestamp.fromDate(settledDate!),
      'keepRecord': keepRecord,
    };
  }
}

