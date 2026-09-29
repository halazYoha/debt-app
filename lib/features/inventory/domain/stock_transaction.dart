import 'package:cloud_firestore/cloud_firestore.dart';

/// The type of stock transaction (stock added or stock sold/deducted)
enum StockTransactionType { stockIn, stockOut }

/// Represents a historical record of stock movement (daily history).
class StockTransaction {
  final String id;
  final String itemName;
  final String unit;
  final double quantity; // always positive; direction is set by [type]
  final double unitPrice;
  final StockTransactionType type; // stockIn = ዕቃ ገባ, stockOut = ተሸጠ
  final DateTime date;
  final String? note; // e.g., "ለተበዳሪ አበበ ተሸጠ", "አዲስ ዕቃ ገዛ"

  const StockTransaction({
    required this.id,
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.type,
    required this.date,
    this.note,
  });

  double get totalValue => quantity * unitPrice;
  bool get isStockIn => type == StockTransactionType.stockIn;

  factory StockTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockTransaction(
      id: doc.id,
      itemName: data['itemName'] ?? '',
      unit: data['unit'] ?? 'ኪሎ',
      quantity: (data['quantity'] ?? 0).toDouble(),
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      type: (data['type'] as String? ?? 'stockIn') == 'stockIn'
          ? StockTransactionType.stockIn
          : StockTransactionType.stockOut,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'itemName': itemName,
    'unit': unit,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'type': type == StockTransactionType.stockIn ? 'stockIn' : 'stockOut',
    'date': Timestamp.fromDate(date),
    if (note != null) 'note': note,
  };
}
