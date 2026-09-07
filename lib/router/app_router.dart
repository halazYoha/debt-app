import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/debt/presentation/add_debtor_screen.dart';
import '../features/debt/presentation/debtor_detail_screen.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/debt/domain/debtor.dart';

import '../features/creditor/presentation/add_creditor_screen.dart';
import '../features/creditor/presentation/creditor_detail_screen.dart';
import '../features/creditor/domain/creditor.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

void navigateToDebtorDetail(String debtorId) {
  final context = rootNavigatorKey.currentContext;
  if (context != null) {
    context.go('/debtor/$debtorId');
  }
}

void navigateToCreditorDetail(String creditorId) {
  final context = rootNavigatorKey.currentContext;
  if (context != null) {
    context.go('/creditor/$creditorId');
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final isAuthenticated = authState.value != null;
      
      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'add_debtor',
            builder: (context, state) => const AddDebtorScreen(),
          ),
          GoRoute(
            path: 'debtor/:id',
            builder: (context, state) {
              final debtorId = state.pathParameters['id']!;
              final initialDebtor = state.extra as Debtor?;
              return DebtorDetailScreen(
                debtorId: debtorId,
                initialDebtor: initialDebtor,
              );
            },
          ),
          GoRoute(
            path: 'add_creditor',
            builder: (context, state) => const AddCreditorScreen(),
          ),
          GoRoute(
            path: 'creditor/:id',
            builder: (context, state) {
              final creditorId = state.pathParameters['id']!;
              final initialCreditor = state.extra as Creditor?;
              return CreditorDetailScreen(
                creditorId: creditorId,
                initialCreditor: initialCreditor,
              );
            },
          ),
        ],
      ),
    ],
  );
});
