import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../creditor/data/creditor_repository.dart';
import '../../debt/data/debt_repository.dart';
import '../../../core/ethiopian_date.dart';
import '../../../core/offline_banner.dart';
import '../../../core/app_drawer.dart';

enum DebtorFilter { all, over50k }
enum HomeTab { debtors, creditors }

class ActiveHomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.debtors;

  void selectTab(HomeTab tab) => state = tab;
}

final activeHomeTabProvider =
    NotifierProvider<ActiveHomeTabNotifier, HomeTab>(ActiveHomeTabNotifier.new);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  DebtorFilter _selectedFilter = DebtorFilter.all;
  bool _amountVisible = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ስልክ ቁጥር አልተመዘገበም'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        await launchUrl(launchUri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ስልክ መደወል አልተቻለም: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeHomeTabProvider);
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(activeTab == HomeTab.debtors ? 'ዋና ገጽ - የደንበኞች ዕዳ' : 'ዋና ገጽ - የእኔ ዕዳ'),
      ),
      body: OfflineAwareScaffoldBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode Switcher Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ref.read(activeHomeTabProvider.notifier).selectTab(HomeTab.debtors);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: activeTab == HomeTab.debtors
                                ? const Color(0xFF10B981)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: activeTab == HomeTab.debtors ? Colors.white : onSurfaceColor,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'የደንበኞች ዕዳ',
                                style: TextStyle(
                                  color: activeTab == HomeTab.debtors ? Colors.white : onSurfaceColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ref.read(activeHomeTabProvider.notifier).selectTab(HomeTab.creditors);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: activeTab == HomeTab.creditors
                                ? const Color(0xFFF59E0B)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: activeTab == HomeTab.creditors ? Colors.white : onSurfaceColor,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'የእኔ ዕዳ',
                                style: TextStyle(
                                  color: activeTab == HomeTab.creditors ? Colors.white : onSurfaceColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Main Content Switcher ──────────────────────────────────────
            Expanded(
              child: activeTab == HomeTab.debtors
                  ? _buildDebtorsView(ref, onSurfaceColor)
                  : _buildCreditorsView(ref, onSurfaceColor),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (activeTab == HomeTab.debtors) {
            context.push('/add_debtor');
          } else {
            context.push('/add_creditor');
          }
        },
        backgroundColor: activeTab == HomeTab.debtors
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          activeTab == HomeTab.debtors ? 'ተበዳሪ ጨምር' : 'የእኔ ዕዳ ጨምር',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  // ── Debtors Tab View ───────────────────────────────────────────────────────
  Widget _buildDebtorsView(WidgetRef ref, Color onSurfaceColor) {
    final debtorsAsync = ref.watch(debtorsProvider);

    return debtorsAsync.when(
      data: (allDebtors) {
        final totalOwed = allDebtors.fold(0.0, (sum, item) => sum + item.remainingBalance);
        final over50kCount = allDebtors.where((d) => d.remainingBalance > 50000).length;

        final filteredDebtors = allDebtors.where((debtor) {
          if (_selectedFilter == DebtorFilter.over50k && debtor.remainingBalance <= 50000) {
            return false;
          }
          final query = _searchQuery.toLowerCase();
          if (query.isEmpty) return true;
          return debtor.name.toLowerCase().contains(query) || debtor.phone.contains(query);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Card(
                color: const Color(0xFF10B981),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ጠቅላላ ያልተከፈለ ዕዳ (የሚሰበሰብ)',
                            style: TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _amountVisible = !_amountVisible),
                            child: Icon(
                              _amountVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white54,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _amountVisible
                            ? '${totalOwed.toStringAsFixed(2)} ETB'
                            : '•••••• ETB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ተበዳሪ በስም ወይም ስልክ ፈልግ...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedFilter = DebtorFilter.all),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFilter == DebtorFilter.all
                              ? const Color(0xFF10B981)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFilter == DebtorFilter.all
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'ሁሉም ተበዳሪዎች (${allDebtors.length})',
                            style: TextStyle(
                              color: _selectedFilter == DebtorFilter.all
                                  ? Colors.white
                                  : onSurfaceColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedFilter = DebtorFilter.over50k),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFilter == DebtorFilter.over50k
                              ? const Color(0xFFD97706)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFilter == DebtorFilter.over50k
                                ? const Color(0xFFD97706)
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'ከ 50,000 ብር በላይ ($over50kCount)',
                            style: TextStyle(
                              color: _selectedFilter == DebtorFilter.over50k
                                  ? Colors.white
                                  : onSurfaceColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Text(
                'ተበዳሪዎች',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Debtors List
            Expanded(
              child: allDebtors.isEmpty
                  ? const Center(
                      child: Text('ተበዳሪ አልተጨመረም። ➕ ተበዳሪ ጨምር ይጫኑ!'),
                    )
                  : filteredDebtors.isEmpty
                      ? const Center(
                          child: Text('ለፍለጋዎ ውጤት አልተገኘም።'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: filteredDebtors.length,
                          itemBuilder: (context, index) {
                            final debtor = filteredDebtors[index];
                            final isSettled = debtor.remainingBalance <= 0;
                            final hasPhone = debtor.phone.trim().isNotEmpty;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSettled
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.orange.withValues(alpha: 0.2),
                                  child: Text(
                                    debtor.name.isNotEmpty
                                        ? debtor.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: isSettled
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(debtor.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  hasPhone
                                      ? '${debtor.phone} · ${EthiopianDate.formatShort(debtor.borrowedDate)}'
                                      : EthiopianDate.formatShort(
                                          debtor.borrowedDate),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.call,
                                        color: hasPhone
                                            ? const Color(0xFF10B981)
                                            : Colors.grey.shade400,
                                        size: 22,
                                      ),
                                      onPressed: () => _makePhoneCall(
                                          context, debtor.phone),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${debtor.remainingBalance.toStringAsFixed(2)} ETB',
                                          style: TextStyle(
                                            color: isSettled
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          isSettled ? 'ተከፍሏል' : 'ይቀራል',
                                          style: TextStyle(
                                            color: isSettled
                                                ? Colors.green
                                                : Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  context.push('/debtor/${debtor.id}',
                                      extra: debtor);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ── Creditors Tab View ─────────────────────────────────────────────────────
  Widget _buildCreditorsView(WidgetRef ref, Color onSurfaceColor) {
    final creditorsAsync = ref.watch(creditorsProvider);

    return creditorsAsync.when(
      data: (allCreditors) {
        final totalIOwe = allCreditors.fold(0.0, (sum, item) => sum + item.remainingBalance);

        final filteredCreditors = allCreditors.where((creditor) {
          final query = _searchQuery.toLowerCase();
          if (query.isEmpty) return true;
          return creditor.name.toLowerCase().contains(query) || creditor.phone.contains(query);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Card(
                color: const Color(0xFFF59E0B),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ጠቅላላ የእኔ ዕዳ (ለሰዎች የሚከፈል)',
                            style: TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _amountVisible = !_amountVisible),
                            child: Icon(
                              _amountVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white54,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _amountVisible
                            ? '${totalIOwe.toStringAsFixed(2)} ETB'
                            : '•••••• ETB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'አቅራቢ/የሰጠኝን ሰው በስም ወይም ስልክ ፈልግ...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Text(
                'የወሰድኳቸው ዕዳዎች (አቅራቢዎች)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Creditors List
            Expanded(
              child: allCreditors.isEmpty
                  ? const Center(
                      child: Text('ምንም የእኔ ዕዳ አልተመዘገበም። ➕ የእኔ ዕዳ ጨምር ይጫኑ!'),
                    )
                  : filteredCreditors.isEmpty
                      ? const Center(
                          child: Text('ለፍለጋዎ ውጤት አልተገኘም።'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: filteredCreditors.length,
                          itemBuilder: (context, index) {
                            final creditor = filteredCreditors[index];
                            final isSettled = creditor.remainingBalance <= 0;
                            final hasPhone = creditor.phone.trim().isNotEmpty;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSettled
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.amber.withValues(alpha: 0.2),
                                  child: Text(
                                    creditor.name.isNotEmpty
                                        ? creditor.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: isSettled
                                          ? Colors.green
                                          : Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(creditor.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  hasPhone
                                      ? '${creditor.phone} · ${EthiopianDate.formatShort(creditor.borrowedDate)}'
                                      : EthiopianDate.formatShort(
                                          creditor.borrowedDate),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.call,
                                        color: hasPhone
                                            ? const Color(0xFFF59E0B)
                                            : Colors.grey.shade400,
                                        size: 22,
                                      ),
                                      onPressed: () => _makePhoneCall(
                                          context, creditor.phone),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${creditor.remainingBalance.toStringAsFixed(2)} ETB',
                                          style: TextStyle(
                                            color: isSettled
                                                ? Colors.green
                                                : Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          isSettled ? 'ከፍያለሁ' : 'እከፍላለሁ',
                                          style: TextStyle(
                                            color: isSettled
                                                ? Colors.green
                                                : Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  context.push('/creditor/${creditor.id}',
                                      extra: creditor);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
