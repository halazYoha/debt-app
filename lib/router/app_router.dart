import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/debt/presentation/add_debtor_screen.dart';
import '../features/debt/presentation/debtor_detail_screen.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/debt/domain/debtor.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
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
              final debtor = state.extra as Debtor;
              return DebtorDetailScreen(debtor: debtor);
            },
          ),
        ],
      ),
    ],
  );
});
