import 'package:cloud_firestore/cloud_firestore.dart';
import '../../debt/domain/debtor.dart';

/// Represents a creditor / supplier from whom the shopkeeper borrowed money or items (Accounts Payable / የእኔ ዕዳ).
class Creditor {
  final String id;
  final String name; // Creditor / Supplier name (e.g., "አበበ ጅምላ")
  final String phone; // Contact phone number
  final List<DebtItem> items; // Items/cash borrowed by shopkeeper
  final List<RepaymentRecord> repayments; // Repayments made BY shopkeeper TO creditor
  final double totalPaid;
  final DateTime borrowedDate;
  final DateTime lastTransactionDate;
  final DateTime? settledDate;
  final bool keepRecord;

  Creditor({
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

  /// Total borrowed by the shopkeeper from this creditor
  double get totalBorrowed => items.fold(0.0, (acc, item) => acc + item.subtotal);

  double get remainingBalance => (totalBorrowed - totalPaid).clamp(0.0, double.infinity);
  bool get isFullyPaid => remainingBalance <= 0;

  String get itemsSummary => items.map((i) => '${i.quantity} ${i.unit} ${i.name}').join(', ');

  int? get daysUntilDelete {
    if (!isFullyPaid || settledDate == null || keepRecord) return null;
    final daysSinceSettled = DateTime.now().difference(settledDate!).inDays;
    return (30 - daysSinceSettled).clamp(0, 30);
  }

  bool get isWarningAutoDelete {
    if (!isFullyPaid || settledDate == null || keepRecord) return false;
    final remaining = daysUntilDelete;
    return remaining != null && remaining <= 5 && remaining > 0;
  }

  bool get shouldAutoDelete {
    if (!isFullyPaid || settledDate == null || keepRecord) return false;
    final daysSinceSettled = DateTime.now().difference(settledDate!).inDays;
    return daysSinceSettled >= 30;
  }

  factory Creditor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<DebtItem> itemsList = [];
    final rawItems = data['items'];
    if (rawItems is List) {
      itemsList = rawItems
          .whereType<Map<String, dynamic>>()
          .map((m) => DebtItem.fromMap(m))
          .toList();
    } else {
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

    List<RepaymentRecord> repaymentsList = [];
    final rawRepayments = data['repayments'];
    if (rawRepayments is List && rawRepayments.isNotEmpty) {
      repaymentsList = rawRepayments
          .whereType<Map<String, dynamic>>()
          .map((m) => RepaymentRecord.fromMap(m))
          .toList();
    } else if (totalPaidVal > 0) {
      repaymentsList = [
        RepaymentRecord(
          amount: totalPaidVal,
          date: lastTxDate,
          note: 'የቀደመ ክፍያ',
        ),
      ];
    }

    return Creditor(
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
      'totalBorrowed': totalBorrowed,
      'totalPaid': totalPaid,
      'borrowedDate': Timestamp.fromDate(borrowedDate),
      'lastTransactionDate': Timestamp.fromDate(lastTransactionDate),
      if (settledDate != null) 'settledDate': Timestamp.fromDate(settledDate!),
      'keepRecord': keepRecord,
    };
  }
}
