import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_repository.dart';
import 'license/license_model.dart';
import 'license/license_provider.dart';
import 'services/export_backup_service.dart';

import '../features/home/presentation/home_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _showExportBottomSheet(BuildContext context) {
    final exportService = ExportBackupService();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'የመረጃ ባክአፕ እና ኤክስፖርት ቋት',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'የደንበኞች እና የአበዳሪዎች መረጃ ሴቭ የሚያደርጉበትን ፎርማት ይምረጡ:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Colors.green),
                  ),
                  title: const Text('Excel / CSV ሠንጠረዥ (Spreadsheet)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('በ Excel ወይም Google Sheets ለመክፈት እና ለማንበብ'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await exportService.exportToCsv();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ስህተት ተከሰተ: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: Colors.blue),
                  ),
                  title: const Text('የሙሉ መረጃ JSON ባክአፕ (Full Backup)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('በሌላ ስልክ ወይም በኋላ መረጃዎችን መልሶ ለመጠቀም (Restore)'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await exportService.exportToJsonBackup();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ስህተት ተከሰተ: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notes_rounded, color: Colors.amber),
                  ),
                  title: const Text('የጽሁፍ ማጠቃለያ (Text Summary)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('በ WhatsApp ወይም Telegram በፍጥነት ለማጋራት'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await exportService.exportToTextSummary();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ስህተት ተከሰተ: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleRestore(BuildContext context) async {
    final exportService = ExportBackupService();

    // Show confirmation dialog before pick
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('መረጃዎችን መልስ (Restore)', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'የቀደመ የ JSON ባክአፕ ፋይል በመምረጥ የመተግበሪያውን መረጃዎች ይመልሱ።\n\n'
          'አዳዲስ መረጃዎች አይሰረዙም፤ የነበሩ መረጃዎች በባክአፕ ፋይሉ መሠረት ይታደሳሉ።',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ሰርዝ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ፋይል ምረጥ (Select File)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('መረጃዎች በመመለስ ላይ ናቸው...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await exportService.restoreFromJson();

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        if (result == null) {
          // User cancelled file picker
          return;
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('መረጃዎች በተሳካ ሁኔታ ተመልሰዋል! ✅'),
            content: Text(
              '• አዲስ የገቡ ተበዳሪዎች: ${result.debtorsRestored}\n'
              '• አዲስ የገቡ አበዳሪዎች: ${result.creditorsRestored}\n'
              '• የታደሱ/የተዋሃዱ መዝገቦች: ${result.mergedCount}\n\n'
              'ጠቅላላ ተፅዕኖ ያረፈባቸው መዝገቦች: ${result.totalRestored + result.mergedCount}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('እሺ (OK)'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ስህተት ተከሰተ! ❌'),
            content: Text('መረጃዎችን መመለስ አልተቻለም:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('እሺ'),
              ),
            ],
          ),
        );
      }
    }
  }

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
            leading: const Icon(Icons.store_rounded, color: Color(0xFF8B5CF6)),
            title: const Text(
              'የሱቅ ዕቃዎች እና ሀብት',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('ክምችት፣ ዋጋ እና የዛሬ ታሪክ', style: TextStyle(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              context.push('/inventory');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF2563EB)),
            title: const Text(
              'የመረጃ ባክአፕ እና ኤክስፖርት',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('በ Excel, WhatsApp ወይም JSON ሴቭ አድርግ', style: TextStyle(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              _showExportBottomSheet(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF059669)),
            title: const Text(
              'መረጃዎችን መልስ (Restore)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('ከዚህ ቀደም የተቀመጠ ባክአፕ አስገባ', style: TextStyle(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              _handleRestore(context);
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
                        color: Colors.green.withValues(alpha: 0.1),
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
                      color: Colors.amber.withValues(alpha: 0.12),
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
                error: (_, _) => const SizedBox(),
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
