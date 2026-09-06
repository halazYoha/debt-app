import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_error_mapper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/debtor.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    throw Exception('እባክዎ መጀመሪያ ይግቡ።');
  }
  return DebtRepository(FirebaseFirestore.instance, user.uid);
});

final debtorsProvider = StreamProvider<List<Debtor>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(debtRepositoryProvider).watchDebtors();
});

class DebtRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  DebtRepository(this._firestore, this._userId);

  CollectionReference get _debtorsRef =>
      _firestore.collection('users').doc(_userId).collection('debtors');

  Stream<List<Debtor>> watchDebtors() {
    return _debtorsRef
        .orderBy('lastTransactionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final debtors =
          snapshot.docs.map((doc) => Debtor.fromFirestore(doc)).toList();

      // Auto-delete records settled more than 30 days ago (fire-and-forget)
      for (final debtor in debtors.where((d) => d.shouldAutoDelete)) {
        deleteDebtor(debtor.id);
      }

      // Return only records that are NOT past the auto-delete threshold
      return debtors.where((d) => !d.shouldAutoDelete).toList();
    });
  }

  Future<void> addDebtor(Debtor debtor) async {
    try {
      await _debtorsRef.add(debtor.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> updateDebtor(Debtor debtor) async {
    try {
      await _debtorsRef.doc(debtor.id).update(debtor.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteDebtor(String id) async {
    try {
      await _debtorsRef.doc(id).delete();
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> keepDebtorRecord(String id) async {
    try {
      await _debtorsRef.doc(id).update({'keepRecord': true});
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }
}
