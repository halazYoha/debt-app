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

final singleDebtorStreamProvider =
    StreamProvider.family<Debtor?, String>((ref, debtorId) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(debtRepositoryProvider).watchDebtor(debtorId);
});

class DebtRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  DebtRepository(this._firestore, this._userId);

  CollectionReference get _debtorsRef =>
      _firestore.collection('users').doc(_userId).collection('debtors');

  Stream<Debtor?> watchDebtor(String id) {
    return _debtorsRef.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Debtor.fromFirestore(doc);
    });
  }

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
      final docRef = debtor.id.isNotEmpty ? _debtorsRef.doc(debtor.id) : _debtorsRef.doc();
      await docRef.set(debtor.toFirestore()).timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {},
          );
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> updateDebtor(Debtor debtor) async {
    try {
      await _debtorsRef.doc(debtor.id).update(debtor.toFirestore()).timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {},
          );
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteDebtor(String id) async {
    try {
      await _debtorsRef.doc(id).delete().timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {},
          );
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> keepDebtorRecord(String id) async {
    try {
      await _debtorsRef.doc(id).update({'keepRecord': true}).timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {},
          );
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> updateDebtorNameAndPhone(String id, String name, String phone) async {
    try {
      await _debtorsRef.doc(id).update({
        'name': name.trim(),
        'phone': phone.trim(),
      }).timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {},
          );
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteRepayment(Debtor debtor, int index) async {
    try {
      final updatedRepayments = List<RepaymentRecord>.from(debtor.repayments)
        ..removeAt(index);
      final newTotalPaid =
          updatedRepayments.fold<double>(0.0, (acc, r) => acc + r.amount);
      final isNowUnpaid = (debtor.totalBorrowed - newTotalPaid) > 0;
      final updated = Debtor(
        id: debtor.id,
        name: debtor.name,
        phone: debtor.phone,
        items: debtor.items,
        repayments: updatedRepayments,
        totalPaid: newTotalPaid,
        borrowedDate: debtor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate: isNowUnpaid ? null : debtor.settledDate,
        keepRecord: debtor.keepRecord,
      );
      await _debtorsRef.doc(debtor.id).update(updated.toFirestore()).timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {},
          );
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> editRepayment(
      Debtor debtor, int index, double newAmount, String? newNote) async {
    try {
      final old = debtor.repayments[index];
      final updatedRepayments = List<RepaymentRecord>.from(debtor.repayments);
      updatedRepayments[index] = RepaymentRecord(
        amount: newAmount,
        date: old.date,
        note: newNote?.trim().isNotEmpty == true ? newNote!.trim() : old.note,
      );
      final newTotalPaid =
          updatedRepayments.fold<double>(0.0, (acc, r) => acc + r.amount);
      final isNowFullyPaid = newTotalPaid >= debtor.totalBorrowed;
      final isNowUnpaid = !isNowFullyPaid;
      final updated = Debtor(
        id: debtor.id,
        name: debtor.name,
        phone: debtor.phone,
        items: debtor.items,
        repayments: updatedRepayments,
        totalPaid: newTotalPaid,
        borrowedDate: debtor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate: isNowUnpaid
            ? null
            : (debtor.settledDate ?? DateTime.now()),
        keepRecord: debtor.keepRecord,
      );
      await _debtorsRef.doc(debtor.id).update(updated.toFirestore()).timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {},
          );
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }
}
