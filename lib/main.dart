import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'router/app_router.dart';
import 'core/theme.dart';
import 'firebase_options.dart';

import 'core/notification_service.dart';
import 'core/background_worker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Firestore offline persistence — the app works without internet.
    // All reads serve from local disk cache; writes are queued and auto-synced.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize notification service & background worker
    await NotificationService().initialize(
      onSelectNotification: (debtorId) {
        if (debtorId != null && debtorId.isNotEmpty) {
          navigateToDebtorDetail(debtorId);
        }
      },
    );
    await NotificationService().requestPermissions();
    await BackgroundWorker.initialize();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  runApp(const ProviderScope(child: DebtApp()));
}

class DebtApp extends ConsumerWidget {
  const DebtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'DebtTracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
