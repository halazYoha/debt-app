import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import '../features/debt/domain/debtor.dart';
import 'notification_service.dart';

const String debtorReminderTask = 'debtorReminderTask';
const String _keyNotificationsEnabled = 'notifications_enabled';
const String _keyReminderDays = 'reminder_days';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
      final reminderDays = prefs.getInt(_keyReminderDays) ?? 15;

      if (!enabled) {
        return Future.value(true);
      }

      // Initialize Firebase in background isolate if needed
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Initialize NotificationService
      await NotificationService().initialize();

      // Fetch debtors across users or current active debtors
      final querySnapshot =
          await FirebaseFirestore.instance.collectionGroup('debtors').get();

      int notifiedCount = 0;
      final now = DateTime.now();

      for (final doc in querySnapshot.docs) {
        if (notifiedCount >= 5) break; // Limit notifications per run

        try {
          final debtor = Debtor.fromFirestore(doc);
          if (debtor.isFullyPaid || debtor.remainingBalance <= 0) continue;

          // Determine last payment date
          DateTime lastPaymentDate = debtor.borrowedDate;
          if (debtor.repayments.isNotEmpty) {
            // Find latest repayment date
            lastPaymentDate = debtor.repayments
                .map((r) => r.date)
                .reduce((a, b) => a.isAfter(b) ? a : b);
          } else if (debtor.lastTransactionDate.isAfter(debtor.borrowedDate)) {
            lastPaymentDate = debtor.lastTransactionDate;
          }

          final daysSincePayment = now.difference(lastPaymentDate).inDays;

          if (daysSincePayment >= reminderDays) {
            await NotificationService().showDebtorReminder(
              id: debtor.id.hashCode,
              debtorId: debtor.id,
              name: debtor.name,
              remainingBalance: debtor.remainingBalance,
              daysSincePayment: daysSincePayment,
            );
            notifiedCount++;
          }
        } catch (e) {
          debugPrint('Error processing debtor doc for reminder: $e');
        }
      }

      return Future.value(true);
    } catch (e) {
      debugPrint('Error in background worker: $e');
      return Future.value(false);
    }
  });
}

class BackgroundWorker {
  static Future<void> initialize() async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await Workmanager().initialize(
        callbackDispatcher,
      );

      // Schedule daily periodic task
      await Workmanager().registerPeriodicTask(
        'debtor_reminder_periodic_task',
        debtorReminderTask,
        frequency: const Duration(hours: 24),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
    }
  }
}
