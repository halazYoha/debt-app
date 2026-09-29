import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single product/item in the shop's stock inventory (የሱቅ ዕቃ ክምችት).
class StockItem {
  final String id;
  final String name; // e.g., "ስኳር", "ዘይት", "ዱቄት"
  final double quantity; // e.g., 50.0 (in kg, liters, bags, pcs)
  final String unit; // e.g., "ኪሎ", "ሊትር", "ባሌ", "ቁጥር"
  final double unitPrice; // Price per unit in ETB (e.g., 120.0 ETB)
  final DateTime lastUpdated;
  final double lowStockThreshold; // e.g., warning if quantity <= 5.0

  const StockItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lastUpdated,
    this.lowStockThreshold = 5.0,
  });

  double get totalValue => quantity * unitPrice;
  bool get isLowStock => quantity > 0 && quantity <= lowStockThreshold;
  bool get isOutOfStock => quantity <= 0;

  factory StockItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'ኪሎ',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lowStockThreshold: (data['lowStockThreshold'] ?? 5.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'lastUpdated': Timestamp.fromDate(lastUpdated),
    'lowStockThreshold': lowStockThreshold,
  };

  StockItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    double? unitPrice,
    DateTime? lastUpdated,
    double? lowStockThreshold,
  }) {
    return StockItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }
}
