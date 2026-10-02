import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/inventory_repository.dart';
import '../domain/stock_item.dart';
import '../domain/stock_transaction.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    throw Exception('እባክዎ መጀመሪያ ይግቡ።');
  }
  return InventoryRepository(FirebaseFirestore.instance, user.uid);
});

/// Real-time stream of all inventory items
final inventoryStreamProvider = StreamProvider<List<StockItem>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(inventoryRepositoryProvider).watchInventory();
});

/// Real-time stream of today's transactions
final todayTransactionsProvider = StreamProvider<List<StockTransaction>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(inventoryRepositoryProvider).watchTodayTransactions();
});

/// Real-time stream of last 30 days transactions
final recentTransactionsProvider = StreamProvider<List<StockTransaction>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(inventoryRepositoryProvider).watchRecentTransactions();
});
