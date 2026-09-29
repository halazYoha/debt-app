import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/stock_item.dart';
import '../domain/stock_transaction.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository();
});

/// Real-time stream of all inventory items
final inventoryStreamProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchInventory();
});

/// Real-time stream of today's transactions
final todayTransactionsProvider = StreamProvider<List<StockTransaction>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchTodayTransactions();
});

/// Real-time stream of last 30 days transactions
final recentTransactionsProvider = StreamProvider<List<StockTransaction>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchRecentTransactions();
});
