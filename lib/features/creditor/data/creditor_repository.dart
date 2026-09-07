import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_error_mapper.dart';
import '../../auth/data/auth_repository.dart';
import '../../debt/domain/debtor.dart';
import '../domain/creditor.dart';

final creditorRepositoryProvider = Provider<CreditorRepository>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    throw Exception('እባክዎ መጀመሪያ ይግቡ።');
  }
  return CreditorRepository(FirebaseFirestore.instance, user.uid);
});

final creditorsProvider = StreamProvider<List<Creditor>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(creditorRepositoryProvider).watchCreditors();
});

final singleCreditorStreamProvider =
    StreamProvider.family<Creditor?, String>((ref, creditorId) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(creditorRepositoryProvider).watchCreditor(creditorId);
});

final creditorRepaymentsStreamProvider =
    StreamProvider.family<List<RepaymentRecord>, String>((ref, creditorId) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return Stream.value([]);
  }
  return ref.watch(creditorRepositoryProvider).watchRepayments(creditorId);
});

class CreditorRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  CreditorRepository(this._firestore, this._userId);

  CollectionReference get _creditorsRef =>
      _firestore.collection('users').doc(_userId).collection('creditors');

  CollectionReference _repaymentsRef(String creditorId) =>
      _creditorsRef.doc(creditorId).collection('repayments');

  Stream<Creditor?> watchCreditor(String id) {
    return _creditorsRef.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Creditor.fromFirestore(doc);
    });
  }

  Stream<List<RepaymentRecord>> watchRepayments(String creditorId) {
    return _repaymentsRef(creditorId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RepaymentRecord.fromMap(
                  doc.data() as Map<String, dynamic>,
                  id: doc.id,
                ))
            .toList());
  }

  Stream<List<Creditor>> watchCreditors() {
    return _creditorsRef
        .orderBy('lastTransactionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final creditors =
          snapshot.docs.map((doc) => Creditor.fromFirestore(doc)).toList();

      for (final creditor in creditors.where((c) => c.shouldAutoDelete)) {
        deleteCreditor(creditor.id);
      }

      return creditors.where((c) => !c.shouldAutoDelete).toList();
    });
  }

  Future<void> addCreditor(Creditor creditor) async {
    try {
      final docRef = creditor.id.isNotEmpty
          ? _creditorsRef.doc(creditor.id)
          : _creditorsRef.doc();
      await docRef.set(creditor.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> updateCreditor(Creditor creditor) async {
    try {
      await _creditorsRef.doc(creditor.id).update(creditor.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> updateSettledDate(Creditor creditor, DateTime settledAt) async {
    try {
      await _creditorsRef.doc(creditor.id).update({
        'settledDate': Timestamp.fromDate(settledAt),
        'lastTransactionDate': Timestamp.fromDate(settledAt),
      });
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteCreditor(String id) async {
    try {
      await _creditorsRef.doc(id).delete();
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> keepCreditorRecord(String id) async {
    try {
      await _creditorsRef.doc(id).update({'keepRecord': true});
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> updateCreditorNameAndPhone(
      String id, String name, String phone) async {
    try {
      await _creditorsRef.doc(id).update({
        'name': name.trim(),
        'phone': phone.trim(),
      });
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> addRepayment(Creditor creditor, RepaymentRecord repayment) async {
    try {
      final newTotalPaid = creditor.totalPaid + repayment.amount;
      final isNowSettled = newTotalPaid >= creditor.totalBorrowed;
      final now = DateTime.now();

      await _repaymentsRef(creditor.id).add(repayment.toMap());

      final Map<String, dynamic> update = {
        'totalPaid': newTotalPaid,
        'lastTransactionDate': Timestamp.fromDate(now),
        if (isNowSettled && creditor.settledDate == null)
          'settledDate': Timestamp.fromDate(now),
      };
      await _creditorsRef.doc(creditor.id).update(update);
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteRepayment(Creditor creditor, RepaymentRecord repayment,
      List<RepaymentRecord> allRepayments) async {
    try {
      if (repayment.id.isNotEmpty) {
        await _repaymentsRef(creditor.id).doc(repayment.id).delete();
      }

      final remaining =
          allRepayments.where((r) => r.id != repayment.id).toList();
      final newTotalPaid =
          remaining.fold<double>(0.0, (acc, r) => acc + r.amount);
      final isNowUnpaid = (creditor.totalBorrowed - newTotalPaid) > 0;

      final Map<String, dynamic> update = {
        'totalPaid': newTotalPaid,
        'lastTransactionDate': Timestamp.fromDate(DateTime.now()),
        if (isNowUnpaid) 'settledDate': FieldValue.delete(),
      };
      await _creditorsRef.doc(creditor.id).update(update);
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> editRepayment(
      Creditor creditor,
      RepaymentRecord repayment,
      double newAmount,
      String? newNote,
      List<RepaymentRecord> allRepayments) async {
    try {
      final updatedRecord = RepaymentRecord(
        id: repayment.id,
        amount: newAmount,
        date: repayment.date,
        note:
            newNote?.trim().isNotEmpty == true ? newNote!.trim() : repayment.note,
      );

      if (repayment.id.isNotEmpty) {
        await _repaymentsRef(creditor.id)
            .doc(repayment.id)
            .update(updatedRecord.toMap());
      }

      final newTotalPaid = allRepayments.fold<double>(0.0, (acc, r) {
        return acc + (r.id == repayment.id ? newAmount : r.amount);
      });
      final isNowFullyPaid = newTotalPaid >= creditor.totalBorrowed;

      final Map<String, dynamic> update = {
        'totalPaid': newTotalPaid,
        'lastTransactionDate': Timestamp.fromDate(DateTime.now()),
        if (isNowFullyPaid && creditor.settledDate == null)
          'settledDate':
              Timestamp.fromDate(creditor.settledDate ?? DateTime.now()),
        if (!isNowFullyPaid) 'settledDate': FieldValue.delete(),
      };
      await _creditorsRef.doc(creditor.id).update(update);
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> editDebtItem(
      Creditor creditor, int itemIndex, DebtItem updatedItem) async {
    try {
      final updatedItems = List<DebtItem>.from(creditor.items);
      updatedItems[itemIndex] = updatedItem;

      final newTotalBorrowed =
          updatedItems.fold<double>(0.0, (acc, item) => acc + item.subtotal);
      final isNowFullyPaid = creditor.totalPaid >= newTotalBorrowed;
      final isNowUnpaid = !isNowFullyPaid;

      final updated = Creditor(
        id: creditor.id,
        name: creditor.name,
        phone: creditor.phone,
        items: updatedItems,
        repayments: creditor.repayments,
        totalPaid: creditor.totalPaid,
        borrowedDate: creditor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate:
            isNowUnpaid ? null : (creditor.settledDate ?? DateTime.now()),
        keepRecord: creditor.keepRecord,
      );

      await _creditorsRef.doc(creditor.id).update(updated.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }

  Future<void> deleteDebtItem(Creditor creditor, int itemIndex) async {
    try {
      final updatedItems = List<DebtItem>.from(creditor.items)
        ..removeAt(itemIndex);

      final newTotalBorrowed =
          updatedItems.fold<double>(0.0, (acc, item) => acc + item.subtotal);
      final isNowFullyPaid = creditor.totalPaid >= newTotalBorrowed;
      final isNowUnpaid = !isNowFullyPaid;

      final updated = Creditor(
        id: creditor.id,
        name: creditor.name,
        phone: creditor.phone,
        items: updatedItems,
        repayments: creditor.repayments,
        totalPaid: creditor.totalPaid,
        borrowedDate: creditor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate:
            isNowUnpaid ? null : (creditor.settledDate ?? DateTime.now()),
        keepRecord: creditor.keepRecord,
      );

      await _creditorsRef.doc(creditor.id).update(updated.toFirestore());
    } catch (e) {
      throw Exception(AppErrorMapper.toAmharic(e));
    }
  }
}
