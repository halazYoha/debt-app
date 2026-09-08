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

/// Streams repayments from the subcollection for a given debtor.
/// Falls back gracefully — if the debtor has old embedded repayments,
/// those are shown via [Debtor.repayments] until new ones are written.
final repaymentsStreamProvider =
    StreamProvider.family<List<RepaymentRecord>, String>((ref, debtorId) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(debtRepositoryProvider).watchRepayments(debtorId);
});

class DebtRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  DebtRepository(this._firestore, this._userId);

  CollectionReference get _debtorsRef =>
      _firestore.collection('users').doc(_userId).collection('debtors');

  /// Reference to the repayments subcollection for a given debtor
  CollectionReference _repaymentsRef(String debtorId) =>
      _debtorsRef.doc(debtorId).collection('repayments');

  Stream<Debtor?> watchDebtor(String id) {
    return _debtorsRef.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Debtor.fromFirestore(doc);
    });
  }

  /// Streams repayments from the subcollection.
  /// Sorting is handled client-side after merging with legacy data.
  Stream<List<RepaymentRecord>> watchRepayments(String debtorId) {
    return _repaymentsRef(debtorId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RepaymentRecord.fromMap(
                  doc.data() as Map<String, dynamic>,
                  id: doc.id,
                ))
            .toList());
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
      await docRef.set(debtor.toFirestore());
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

  /// Marks a debtor as fully settled with a given date (no repayment added).
  Future<void> updateSettledDate(Debtor debtor, DateTime settledAt) async {
    try {
      await _debtorsRef.doc(debtor.id).update({
        'settledDate': Timestamp.fromDate(settledAt),
        'lastTransactionDate': Timestamp.fromDate(settledAt),
      });
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

  Future<void> updateDebtorNameAndPhone(String id, String name, String phone) async {
    try {
      await _debtorsRef.doc(id).update({
        'name': name.trim(),
        'phone': phone.trim(),
      });
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  /// Adds a new repayment to the subcollection and updates totalPaid on the debtor.
  Future<void> addRepayment(Debtor debtor, RepaymentRecord repayment) async {
    try {
      final newTotalPaid = debtor.totalPaid + repayment.amount;
      final isNowSettled = newTotalPaid >= debtor.totalBorrowed;
      final now = DateTime.now();

      // Write repayment to subcollection
      await _repaymentsRef(debtor.id).add(repayment.toMap());

      // Update summary fields on the debtor document (stays small)
      final Map<String, dynamic> update = {
        'totalPaid': newTotalPaid,
        'lastTransactionDate': Timestamp.fromDate(now),
        if (isNowSettled && debtor.settledDate == null)
          'settledDate': Timestamp.fromDate(now),
      };
      await _debtorsRef.doc(debtor.id).update(update);
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteRepayment(Debtor debtor, RepaymentRecord repayment, List<RepaymentRecord> allRepayments) async {
    try {
      // If this repayment has a subcollection id, delete from subcollection
      if (repayment.id.isNotEmpty) {
        await _repaymentsRef(debtor.id).doc(repayment.id).delete();
      }

      // Recalculate totalPaid from remaining repayments
      final remaining = allRepayments.where((r) => r.id != repayment.id).toList();
      final newTotalPaid = remaining.fold<double>(0.0, (acc, r) => acc + r.amount);
      final isNowUnpaid = (debtor.totalBorrowed - newTotalPaid) > 0;

      final Map<String, dynamic> update = {
        'totalPaid': newTotalPaid,
        'lastTransactionDate': Timestamp.fromDate(DateTime.now()),
        if (isNowUnpaid) 'settledDate': FieldValue.delete(),
      };
      await _debtorsRef.doc(debtor.id).update(update);
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> editRepayment(
      Debtor debtor,
      RepaymentRecord repayment,
      double newAmount,
      String? newNote,
      List<RepaymentRecord> allRepayments,
      {String? newBankName}) async {
    try {
      final updatedRecord = RepaymentRecord(
        id: repayment.id,
        amount: newAmount,
        date: repayment.date,
        note: newNote?.trim().isNotEmpty == true ? newNote!.trim() : repayment.note,
        bankName: newBankName ?? repayment.bankName,
      );

      // Update in subcollection if it has an id (new-style)
      if (repayment.id.isNotEmpty) {
        await _repaymentsRef(debtor.id).doc(repayment.id).update(updatedRecord.toMap());
      }

      // Recalculate totalPaid using the new amount
      final newTotalPaid = allRepayments.fold<double>(0.0, (acc, r) {
        return acc + (r.id == repayment.id ? newAmount : r.amount);
      });
      final isNowFullyPaid = newTotalPaid >= debtor.totalBorrowed;

      final Map<String, dynamic> update = {
        'totalPaid': newTotalPaid,
        'lastTransactionDate': Timestamp.fromDate(DateTime.now()),
        if (isNowFullyPaid && debtor.settledDate == null)
          'settledDate': Timestamp.fromDate(debtor.settledDate ?? DateTime.now()),
        if (!isNowFullyPaid) 'settledDate': FieldValue.delete(),
      };
      await _debtorsRef.doc(debtor.id).update(update);
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> editDebtItem(
      Debtor debtor, int itemIndex, DebtItem updatedItem) async {
    try {
      final updatedItems = List<DebtItem>.from(debtor.items);
      updatedItems[itemIndex] = updatedItem;

      final newTotalBorrowed =
          updatedItems.fold<double>(0.0, (acc, item) => acc + item.subtotal);
      final isNowFullyPaid = debtor.totalPaid >= newTotalBorrowed;
      final isNowUnpaid = !isNowFullyPaid;

      final updated = Debtor(
        id: debtor.id,
        name: debtor.name,
        phone: debtor.phone,
        items: updatedItems,
        repayments: debtor.repayments,
        totalPaid: debtor.totalPaid,
        borrowedDate: debtor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate: isNowUnpaid
            ? null
            : (debtor.settledDate ?? DateTime.now()),
        keepRecord: debtor.keepRecord,
      );

      await _debtorsRef.doc(debtor.id).update(updated.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteDebtItem(Debtor debtor, int itemIndex) async {
    try {
      final updatedItems = List<DebtItem>.from(debtor.items)..removeAt(itemIndex);

      final newTotalBorrowed =
          updatedItems.fold<double>(0.0, (acc, item) => acc + item.subtotal);
      final isNowFullyPaid = debtor.totalPaid >= newTotalBorrowed;
      final isNowUnpaid = !isNowFullyPaid;

      final updated = Debtor(
        id: debtor.id,
        name: debtor.name,
        phone: debtor.phone,
        items: updatedItems,
        repayments: debtor.repayments,
        totalPaid: debtor.totalPaid,
        borrowedDate: debtor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate: isNowUnpaid
            ? null
            : (debtor.settledDate ?? DateTime.now()),
        keepRecord: debtor.keepRecord,
      );

      await _debtorsRef.doc(debtor.id).update(updated.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }
}
