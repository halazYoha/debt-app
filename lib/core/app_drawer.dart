import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_repository.dart';
import 'settings_sheet.dart';
import 'license/license_model.dart';
import 'license/license_provider.dart';

import '../features/home/presentation/home_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final primaryColor = Theme.of(context).primaryColor;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.email != null && user!.email!.isNotEmpty
                    ? user.email![0].toUpperCase()
                    : '👤',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            accountName: const Text(
              'ዕዳ መዝገብ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              user?.email ?? 'ተጠቃሚ',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline_rounded, color: Color(0xFF10B981)),
            title: const Text(
              'የደንበኞች ዕዳ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(activeHomeTabProvider.notifier).selectTab(HomeTab.debtors);
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFF59E0B)),
            title: const Text(
              'የእኔ ዕዳ (የወሰድኩት)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(activeHomeTabProvider.notifier).selectTab(HomeTab.creditors);
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded, color: Color(0xFF3B82F6)),
            title: const Text(
              'ቅንብሮች',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context); // Close drawer
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const SettingsSheet(),
              );
            },
          ),
          const Divider(),
          Consumer(
            builder: (context, ref, child) {
              final licenseAsync = ref.watch(licenseStatusProvider);
              return licenseAsync.when(
                data: (license) {
                  if (license.isActivated) {
                    final planName = license.plan == LicensePlan.permanent
                        ? 'ቋሚ (Permanent)'
                        : license.plan == LicensePlan.annual
                            ? 'ዓመታዊ (Annual)'
                            : 'ወርሃዊ (Monthly)';
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'መተግበሪያው ተነቅሏል ✅',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'ፕላን: $planName',
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final daysLeft = license.trialDaysRemaining;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'የ 30 ቀን ነፃ ሙከራ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '$daysLeft ቀናት ይቀራሉ',
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'ውጣ',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(authRepositoryProvider).signOut();
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'DebtTracker v1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
