import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class RestoreResult {
  final int debtorsRestored;
  final int creditorsRestored;
  final int mergedCount;

  const RestoreResult({
    required this.debtorsRestored,
    required this.creditorsRestored,
    required this.mergedCount,
  });

  int get totalRestored => debtorsRestored + creditorsRestored;
}

class ExportBackupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  void _checkAuth() {
    if (_userId == null) {
      throw Exception('ይቅርታ፣ መጀመሪያ ይግቡ (User is not authenticated)');
    }
  }

  // Helper to safely format CSV fields
  String _csvEscape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// 1. EXPORT TO CSV SPREADSHEET (Excel Compatible)
  Future<void> exportToCsv() async {
    _checkAuth();

    final uid = _userId!;
    final StringBuffer csvBuffer = StringBuffer();

    // CSV Headers
    csvBuffer.writeln(
      'ዓይነት,ስም,ስልክ,ጠቅላላ ዕዳ (ETB),የተከፈለ (ETB),ቀሪ ዕዳ (ETB),የዕቃ ዝርዝር,የመጨረሻ ቀን,ሁኔታ',
    );

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // A. Debtors (ተበዳሪዎች)
    final debtorsSnap = await _db.collection('users').doc(uid).collection('debtors').get();
    for (var doc in debtorsSnap.docs) {
      final data = doc.data();
      final String name = data['name'] ?? '';
      final String phone = data['phone'] ?? '';
      final double totalPaid = (data['totalPaid'] ?? 0).toDouble();

      // Items summary
      List<String> itemNames = [];
      double totalBorrowed = (data['totalBorrowed'] ?? 0).toDouble();
      if (data['items'] is List) {
        for (var item in data['items']) {
          if (item is Map) {
            final qty = item['quantity'] ?? 1;
            final unit = item['unit'] ?? '';
            final iName = item['name'] ?? '';
            itemNames.add('$qty $unit $iName'.trim());
          }
        }
      }

      final double remaining = (totalBorrowed - totalPaid).clamp(0.0, double.infinity);
      final DateTime? lastTx = (data['lastTransactionDate'] as Timestamp?)?.toDate();
      final String status = remaining <= 0 ? 'ተከፍሏል (Settled)' : 'ያልተከፈለ (Pending)';

      csvBuffer.writeln([
        _csvEscape('ተበዳሪ (Debtor)'),
        _csvEscape(name),
        _csvEscape(phone),
        totalBorrowed.toStringAsFixed(2),
        totalPaid.toStringAsFixed(2),
        remaining.toStringAsFixed(2),
        _csvEscape(itemNames.join('; ')),
        lastTx != null ? dateFormat.format(lastTx) : '',
        _csvEscape(status),
      ].join(','));
    }

    // B. Creditors / Suppliers (አበዳሪዎች / ጅምላ)
    final creditorsSnap = await _db.collection('users').doc(uid).collection('creditors').get();
    for (var doc in creditorsSnap.docs) {
      final data = doc.data();
      final String name = data['name'] ?? '';
      final String phone = data['phone'] ?? '';
      final double totalPaid = (data['totalPaid'] ?? 0).toDouble();

      List<String> itemNames = [];
      double totalBorrowed = (data['totalBorrowed'] ?? 0).toDouble();
      if (data['items'] is List) {
        for (var item in data['items']) {
          if (item is Map) {
            final qty = item['quantity'] ?? 1;
            final unit = item['unit'] ?? '';
            final iName = item['name'] ?? '';
            itemNames.add('$qty $unit $iName'.trim());
          }
        }
      }

      final double remaining = (totalBorrowed - totalPaid).clamp(0.0, double.infinity);
      final DateTime? lastTx = (data['lastTransactionDate'] as Timestamp?)?.toDate();
      final String status = remaining <= 0 ? 'ተከፍሏል (Settled)' : 'ያልተከፈለ (Pending)';

      csvBuffer.writeln([
        _csvEscape('አበዳሪ/ጅምላ (Supplier)'),
        _csvEscape(name),
        _csvEscape(phone),
        totalBorrowed.toStringAsFixed(2),
        totalPaid.toStringAsFixed(2),
        remaining.toStringAsFixed(2),
        _csvEscape(itemNames.join('; ')),
        lastTx != null ? dateFormat.format(lastTx) : '',
        _csvEscape(status),
      ].join(','));
    }

    // Save CSV to temp file and share
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filePath = '${tempDir.path}/eda_mezgeb_export_$dateStr.csv';
    final file = File(filePath);
    await file.writeAsString(csvBuffer.toString());

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'የዕዳ መዝገብ CSV ኤክስፖርት ($dateStr)',
    );
  }

  /// 2. EXPORT TO JSON BACKUP (Full Schema for Restore)
  Future<void> exportToJsonBackup() async {
    _checkAuth();

    final uid = _userId!;

    // A. Fetch Debtors & Repayments
    final debtorsSnap = await _db.collection('users').doc(uid).collection('debtors').get();
    final List<Map<String, dynamic>> debtorsList = [];

    for (var doc in debtorsSnap.docs) {
      final data = doc.data();
      final repaymentsSnap = await doc.reference.collection('repayments').get();
      final repaymentsData = repaymentsSnap.docs.map((rDoc) {
        final rMap = rDoc.data();
        return {
          'id': rDoc.id,
          'amount': rMap['amount'],
          'date': (rMap['date'] as Timestamp?)?.toDate().toIso8601String(),
          'note': rMap['note'],
          'bankName': rMap['bankName'],
        };
      }).toList();

      debtorsList.add({
        'id': doc.id,
        'name': data['name'],
        'phone': data['phone'],
        'items': data['items'],
        'totalBorrowed': data['totalBorrowed'],
        'totalPaid': data['totalPaid'],
        'borrowedDate': (data['borrowedDate'] as Timestamp?)?.toDate().toIso8601String(),
        'lastTransactionDate': (data['lastTransactionDate'] as Timestamp?)?.toDate().toIso8601String(),
        'settledDate': (data['settledDate'] as Timestamp?)?.toDate().toIso8601String(),
        'keepRecord': data['keepRecord'] ?? false,
        'repayments': repaymentsData,
      });
    }

    // B. Fetch Creditors & Repayments
    final creditorsSnap = await _db.collection('users').doc(uid).collection('creditors').get();
    final List<Map<String, dynamic>> creditorsList = [];

    for (var doc in creditorsSnap.docs) {
      final data = doc.data();
      final repaymentsSnap = await doc.reference.collection('repayments').get();
      final repaymentsData = repaymentsSnap.docs.map((rDoc) {
        final rMap = rDoc.data();
        return {
          'id': rDoc.id,
          'amount': rMap['amount'],
          'date': (rMap['date'] as Timestamp?)?.toDate().toIso8601String(),
          'note': rMap['note'],
          'bankName': rMap['bankName'],
        };
      }).toList();

      creditorsList.add({
        'id': doc.id,
        'name': data['name'],
        'phone': data['phone'],
        'items': data['items'],
        'totalBorrowed': data['totalBorrowed'],
        'totalPaid': data['totalPaid'],
        'borrowedDate': (data['borrowedDate'] as Timestamp?)?.toDate().toIso8601String(),
        'lastTransactionDate': (data['lastTransactionDate'] as Timestamp?)?.toDate().toIso8601String(),
        'settledDate': (data['settledDate'] as Timestamp?)?.toDate().toIso8601String(),
        'keepRecord': data['keepRecord'] ?? false,
        'repayments': repaymentsData,
      });
    }

    // Combine payload
    final backupPayload = {
      'app': 'eda_mezgeb',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'debtors': debtorsList,
      'creditors': creditorsList,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backupPayload);
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filePath = '${tempDir.path}/eda_mezgeb_backup_$dateStr.json';
    final file = File(filePath);
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'የዕዳ መዝገብ JSON ባክአፕ ($dateStr)',
    );
  }

  /// 3. EXPORT TO TEXT SUMMARY (For WhatsApp / Telegram Share)
  Future<void> exportToTextSummary() async {
    _checkAuth();

    final uid = _userId!;
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // Fetch summaries
    final debtorsSnap = await _db.collection('users').doc(uid).collection('debtors').get();
    final creditorsSnap = await _db.collection('users').doc(uid).collection('creditors').get();

    double totalDebtorBorrowed = 0;
    double totalDebtorPaid = 0;

    for (var doc in debtorsSnap.docs) {
      final d = doc.data();
      totalDebtorBorrowed += (d['totalBorrowed'] ?? 0).toDouble();
      totalDebtorPaid += (d['totalPaid'] ?? 0).toDouble();
    }

    double totalCreditorBorrowed = 0;
    double totalCreditorPaid = 0;

    for (var doc in creditorsSnap.docs) {
      final d = doc.data();
      totalCreditorBorrowed += (d['totalBorrowed'] ?? 0).toDouble();
      totalCreditorPaid += (d['totalPaid'] ?? 0).toDouble();
    }

    final debtorRemaining = (totalDebtorBorrowed - totalDebtorPaid).clamp(0.0, double.infinity);
    final creditorRemaining = (totalCreditorBorrowed - totalCreditorPaid).clamp(0.0, double.infinity);

    final summaryText = StringBuffer()
      ..writeln('📋 የዕዳ መዝገብ ማጠቃለያ ($dateStr)')
      ..writeln('----------------------------------------')
      ..writeln('👥 ተበዳሪዎች (የሚሰበሰብ ዕዳ):')
      ..writeln('  • ብዛት: ${debtorsSnap.docs.length} ሰዎች')
      ..writeln('  • ጠቅላላ ዕዳ: ${totalDebtorBorrowed.toStringAsFixed(0)} ETB')
      ..writeln('  • የተሰበሰበ: ${totalDebtorPaid.toStringAsFixed(0)} ETB')
      ..writeln('  • ቀሪ የሚሰበሰብ: ${debtorRemaining.toStringAsFixed(0)} ETB')
      ..writeln('')
      ..writeln('🏢 አበዳሪዎች/ጅምላ (የሚከፈል ዕዳ):')
      ..writeln('  • ብዛት: ${creditorsSnap.docs.length} ሰዎች')
      ..writeln('  • ጠቅላላ ዕዳ: ${totalCreditorBorrowed.toStringAsFixed(0)} ETB')
      ..writeln('  • የተከፈለ: ${totalCreditorPaid.toStringAsFixed(0)} ETB')
      ..writeln('  • ቀሪ የሚከፈል: ${creditorRemaining.toStringAsFixed(0)} ETB')
      ..writeln('----------------------------------------')
      ..writeln('የተላከው ከዕዳ መዝገብ መተግበሪያ።');

    await Share.share(summaryText.toString(), subject: 'የዕዳ መዝገብ ማጠቃለያ');
  }

  /// 4. SMART RESTORE FROM JSON (Smart Merge Logic)
  Future<RestoreResult?> restoreFromJson() async {
    _checkAuth();

    final uid = _userId!;

    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return null; // User cancelled
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final Map<String, dynamic> backup = jsonDecode(content);

    if (!backup.containsKey('debtors') && !backup.containsKey('creditors')) {
      throw Exception('የተሳሳተ የባክአፕ ፋይል (Invalid backup structure)');
    }

    int debtorsRestored = 0;
    int creditorsRestored = 0;
    int mergedCount = 0;

    // --- RESTORE DEBTORS ---
    final debtorsList = (backup['debtors'] as List?) ?? [];
    for (var d in debtorsList) {
      final String docId = (d['id'] != null && (d['id'] as String).isNotEmpty)
          ? d['id']
          : _db.collection('users').doc(uid).collection('debtors').doc().id;

      final docRef = _db.collection('users').doc(uid).collection('debtors').doc(docId);
      final existingSnap = await docRef.get();

      final Map<String, dynamic> firestoreData = {
        'name': d['name'] ?? '',
        'phone': d['phone'] ?? '',
        'items': d['items'] ?? [],
        'totalBorrowed': (d['totalBorrowed'] ?? 0).toDouble(),
        'totalPaid': (d['totalPaid'] ?? 0).toDouble(),
        'borrowedDate': Timestamp.fromDate(
          d['borrowedDate'] != null ? DateTime.parse(d['borrowedDate']) : DateTime.now(),
        ),
        'lastTransactionDate': Timestamp.fromDate(
          d['lastTransactionDate'] != null
              ? DateTime.parse(d['lastTransactionDate'])
              : DateTime.now(),
        ),
        'keepRecord': d['keepRecord'] ?? false,
      };

      if (d['settledDate'] != null) {
        firestoreData['settledDate'] = Timestamp.fromDate(DateTime.parse(d['settledDate']));
      }

      if (existingSnap.exists) {
        mergedCount++;
        // Merge logic: compare lastTransactionDate, update if backup is newer or has higher paid amount
        final existingData = existingSnap.data()!;
        final existingTxDate = (existingData['lastTransactionDate'] as Timestamp?)?.toDate();
        final backupTxDate = d['lastTransactionDate'] != null
            ? DateTime.parse(d['lastTransactionDate'])
            : null;

        if (backupTxDate != null && (existingTxDate == null || backupTxDate.isAfter(existingTxDate))) {
          await docRef.set(firestoreData, SetOptions(merge: true));
        }
      } else {
        await docRef.set(firestoreData);
        debtorsRestored++;
      }

      // Restore Repayments subcollection
      final repayments = (d['repayments'] as List?) ?? [];
      for (var r in repayments) {
        final rId = (r['id'] != null && (r['id'] as String).isNotEmpty)
            ? r['id']
            : docRef.collection('repayments').doc().id;

        final rRef = docRef.collection('repayments').doc(rId);
        await rRef.set({
          'amount': (r['amount'] ?? 0).toDouble(),
          'date': Timestamp.fromDate(
            r['date'] != null ? DateTime.parse(r['date']) : DateTime.now(),
          ),
          if (r['note'] != null) 'note': r['note'],
          if (r['bankName'] != null) 'bankName': r['bankName'],
        }, SetOptions(merge: true));
      }
    }

    // --- RESTORE CREDITORS ---
    final creditorsList = (backup['creditors'] as List?) ?? [];
    for (var c in creditorsList) {
      final String docId = (c['id'] != null && (c['id'] as String).isNotEmpty)
          ? c['id']
          : _db.collection('users').doc(uid).collection('creditors').doc().id;

      final docRef = _db.collection('users').doc(uid).collection('creditors').doc(docId);
      final existingSnap = await docRef.get();

      final Map<String, dynamic> firestoreData = {
        'name': c['name'] ?? '',
        'phone': c['phone'] ?? '',
        'items': c['items'] ?? [],
        'totalBorrowed': (c['totalBorrowed'] ?? 0).toDouble(),
        'totalPaid': (c['totalPaid'] ?? 0).toDouble(),
        'borrowedDate': Timestamp.fromDate(
          c['borrowedDate'] != null ? DateTime.parse(c['borrowedDate']) : DateTime.now(),
        ),
        'lastTransactionDate': Timestamp.fromDate(
          c['lastTransactionDate'] != null
              ? DateTime.parse(c['lastTransactionDate'])
              : DateTime.now(),
        ),
        'keepRecord': c['keepRecord'] ?? false,
      };

      if (c['settledDate'] != null) {
        firestoreData['settledDate'] = Timestamp.fromDate(DateTime.parse(c['settledDate']));
      }

      if (existingSnap.exists) {
        mergedCount++;
        final existingData = existingSnap.data()!;
        final existingTxDate = (existingData['lastTransactionDate'] as Timestamp?)?.toDate();
        final backupTxDate = c['lastTransactionDate'] != null
            ? DateTime.parse(c['lastTransactionDate'])
            : null;

        if (backupTxDate != null && (existingTxDate == null || backupTxDate.isAfter(existingTxDate))) {
          await docRef.set(firestoreData, SetOptions(merge: true));
        }
      } else {
        await docRef.set(firestoreData);
        creditorsRestored++;
      }

      // Restore Repayments subcollection
      final repayments = (c['repayments'] as List?) ?? [];
      for (var r in repayments) {
        final rId = (r['id'] != null && (r['id'] as String).isNotEmpty)
            ? r['id']
            : docRef.collection('repayments').doc().id;

        final rRef = docRef.collection('repayments').doc(rId);
        await rRef.set({
          'amount': (r['amount'] ?? 0).toDouble(),
          'date': Timestamp.fromDate(
            r['date'] != null ? DateTime.parse(r['date']) : DateTime.now(),
          ),
          if (r['note'] != null) 'note': r['note'],
          if (r['bankName'] != null) 'bankName': r['bankName'],
        }, SetOptions(merge: true));
      }
    }

    return RestoreResult(
      debtorsRestored: debtorsRestored,
      creditorsRestored: creditorsRestored,
      mergedCount: mergedCount,
    );
  }
}
