import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/app_error_mapper.dart';
import '../domain/stock_item.dart';
import '../domain/stock_transaction.dart';

class InventoryRepository {
  final FirebaseFirestore _db;
  final String _userId;

  InventoryRepository(this._db, this._userId);

  CollectionReference<Map<String, dynamic>> get _inventoryRef =>
      _db.collection('users').doc(_userId).collection('inventory');

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _db.collection('users').doc(_userId).collection('stock_transactions');

  // ─── INVENTORY ITEMS ──────────────────────────────────────────────────────

  /// Watch all inventory items as a real-time stream
  Stream<List<StockItem>> watchInventory() {
    return _inventoryRef
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => StockItem.fromFirestore(doc)).toList());
  }

  /// Add a brand new stock item and record a stockIn transaction
  Future<void> addStockItem(StockItem item, {String? note}) async {
    final now = DateTime.now();
    final docRef = _inventoryRef.doc();
    final newItem = item.copyWith(id: docRef.id, lastUpdated: now);

    final batch = _db.batch();

    // Save inventory document
    batch.set(docRef, newItem.toFirestore());

    // Record stock-in transaction
    final txRef = _transactionsRef.doc();
    batch.set(txRef, StockTransaction(
      id: txRef.id,
      itemName: item.name,
      unit: item.unit,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      type: StockTransactionType.stockIn,
      date: now,
      note: note ?? 'አዲስ ዕቃ ተጨምሯል',
    ).toFirestore());

    await batch.commit();
  }

  /// Update an existing stock item's price or other properties
  Future<void> updateStockItem(StockItem item) async {
    await _inventoryRef.doc(item.id).update({
      ...item.toFirestore(),
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Restock (add quantity to existing item) and record stockIn transaction
  Future<void> restockItem(StockItem item, double addedQuantity, {String? note}) async {
    final now = DateTime.now();
    final newQty = item.quantity + addedQuantity;
    final batch = _db.batch();

    // Update inventory quantity
    batch.update(_inventoryRef.doc(item.id), {
      'quantity': newQty,
      'lastUpdated': Timestamp.fromDate(now),
    });

    // Record stock-in transaction
    final txRef = _transactionsRef.doc();
    batch.set(txRef, StockTransaction(
      id: txRef.id,
      itemName: item.name,
      unit: item.unit,
      quantity: addedQuantity,
      unitPrice: item.unitPrice,
      type: StockTransactionType.stockIn,
      date: now,
      note: note ?? 'ዕቃ ተሞልቷል (Restocked)',
    ).toFirestore());

    await batch.commit();
  }

  /// Deduct stock quantity when items are sold/lent to debtors.
  /// Matches by item name (case-insensitive) and deducts quantity.
  Future<void> deductStockQuantity(String itemName, double deductQty, double unitPrice, {String? note}) async {
    if (_userId.isEmpty) return;

    // Find matching inventory item by name
    final snapshot = await _inventoryRef.get();
    final now = DateTime.now();

    QueryDocumentSnapshot<Map<String, dynamic>>? matchedDoc;
    for (final doc in snapshot.docs) {
      final name = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
      if (name == itemName.trim().toLowerCase()) {
        matchedDoc = doc;
        break;
      }
    }

    if (matchedDoc == null) return; // No matching item in inventory — skip

    final currentQty = (matchedDoc.data()['quantity'] as num? ?? 0).toDouble();
    final newQty = (currentQty - deductQty).clamp(0.0, double.infinity);

    final batch = _db.batch();

    // Reduce quantity in inventory
    batch.update(_inventoryRef.doc(matchedDoc.id), {
      'quantity': newQty,
      'lastUpdated': Timestamp.fromDate(now),
    });

    // Record stock-out transaction
    final txRef = _transactionsRef.doc();
    final unit = matchedDoc.data()['unit'] as String? ?? 'ኪሎ';
    batch.set(txRef, StockTransaction(
      id: txRef.id,
      itemName: itemName,
      unit: unit,
      quantity: deductQty,
      unitPrice: unitPrice,
      type: StockTransactionType.stockOut,
      date: now,
      note: note ?? 'ለተበዳሪ ተሸጠ/ተወሰደ',
    ).toFirestore());

    await batch.commit();
  }

  /// Delete a stock item permanently
  Future<void> deleteStockItem(String itemId) async {
    await _inventoryRef.doc(itemId).delete();
  }

  // ─── TRANSACTIONS / DAILY HISTORY ─────────────────────────────────────────

  /// Watch today's stock transactions
  Stream<List<StockTransaction>> watchTodayTransactions() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _transactionsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StockTransaction.fromFirestore(doc))
            .toList());
  }

  /// Watch all transactions (last 30 days) for history view
  Stream<List<StockTransaction>> watchRecentTransactions() {
    final since = DateTime.now().subtract(const Duration(days: 30));
    return _transactionsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StockTransaction.fromFirestore(doc))
            .toList());
  }
}
