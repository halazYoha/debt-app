import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../debt/data/debt_repository.dart';
import '../../../core/ethiopian_date.dart';
import '../../../core/offline_banner.dart';
import '../../../core/app_drawer.dart';

enum DebtorFilter { all, over50k }

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
          content: Text('ለዚህ ተበዳሪ ስልክ ቁጥር አልተመዘገበም'),
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
    final debtorsAsync = ref.watch(debtorsProvider);
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('ዋና ገጽ'),
      ),
      body: debtorsAsync.when(
        data: (allDebtors) {
          final totalOwed = allDebtors.fold(0.0, (sum, item) => sum + item.remainingBalance);
          final over50kCount = allDebtors.where((d) => d.remainingBalance > 50000).length;

          final filteredDebtors = allDebtors.where((debtor) {
            // 1. Amount Filter (based on remaining net balance)
            if (_selectedFilter == DebtorFilter.over50k && debtor.remainingBalance <= 50000) {
              return false;
            }

            // 2. Search Query Filter
            final query = _searchQuery.toLowerCase();
            if (query.isEmpty) return true;
            return debtor.name.toLowerCase().contains(query) || debtor.phone.contains(query);
          }).toList();
          
          return OfflineAwareScaffoldBody(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Theme.of(context).primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'ጠቅላላ ያልተከፈለ ዕዳ',
                              style: TextStyle(color: Colors.white70, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _amountVisible = !_amountVisible),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  _amountVisible ? Icons.visibility : Icons.visibility_off,
                                  key: ValueKey(_amountVisible),
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Text(
                            _amountVisible
                                ? '${totalOwed.toStringAsFixed(2)} ETB'
                                : '•••••• ETB',
                            key: ValueKey(_amountVisible),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Search Bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'በስም ወይም ስልክ ፈልግ...',
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

              // ── Select Buttons for Debtors Filter ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = DebtorFilter.all),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedFilter == DebtorFilter.all
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedFilter == DebtorFilter.all
                                    ? Theme.of(context).primaryColor
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
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = DebtorFilter.over50k),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
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

              // ── Scrollable Debtors List ONLY ─────────────────────────────
              Expanded(
                child: allDebtors.isEmpty
                    ? const Center(
                        child: Text('ተበዳሪ አልተጨመረም። ➕ ተበዳሪ ጨምር ይጫኑ!'),
                      )
                    : _selectedFilter == DebtorFilter.over50k && filteredDebtors.isEmpty
                        ? const Center(
                            child: Text('ከ 50,000 ብር በላይ የተበደረ ደንበኛ የለም።'),
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
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isSettled
                                                ? Colors.green.withValues(alpha: 0.2)
                                                : Colors.orange.withValues(alpha: 0.2),
                                            child: Text(
                                              debtor.name.isNotEmpty ? debtor.name[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                color: isSettled ? Colors.green : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(debtor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                            hasPhone
                                                ? '${debtor.phone} · ${EthiopianDate.formatShort(debtor.borrowedDate)}'
                                                : EthiopianDate.formatShort(debtor.borrowedDate),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.call,
                                                  color: hasPhone ? const Color(0xFF10B981) : Colors.grey.shade400,
                                                  size: 22,
                                                ),
                                                tooltip: hasPhone ? 'ደውል (${debtor.phone})' : 'ስልክ ቁጥር አልተመዘገበም',
                                                onPressed: () => _makePhoneCall(context, debtor.phone),
                                              ),
                                              const SizedBox(width: 4),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${debtor.remainingBalance.toStringAsFixed(2)} ETB',
                                                    style: TextStyle(
                                                      color: isSettled ? Colors.green : Colors.red,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  Text(
                                                    isSettled ? 'ተከፍሏል' : 'ይቀራል',
                                                    style: TextStyle(
                                                      color: isSettled ? Colors.green : Colors.grey,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (isSettled) ...[
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline,
                                                      color: Colors.red, size: 22),
                                                  tooltip: 'መዝገብ ሰርዝ',
                                                  onPressed: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(20)),
                                                        title: const Row(
                                                          children: [
                                                            Icon(Icons.delete_forever,
                                                                color: Colors.red),
                                                            SizedBox(width: 8),
                                                            Text('መዝገብ መሰረዝ'),
                                                          ],
                                                        ),
                                                        content: Text(
                                                            '${debtor.name} የተከፈለ መዝገብ ከአሁኑ በቋሚነት መሰረዝ ይፈልጋሉ?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(ctx, false),
                                                            child: const Text('ሰርዝ'),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(ctx, true),
                                                            style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.red),
                                                            child: const Text('አዎ፣ ሰርዝ'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      await ref
                                                          .read(debtRepositoryProvider)
                                                          .deleteDebtor(debtor.id);
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text('መዝገብ ተሰርዟል! 🗑️'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                          onTap: () {
                                            context.push('/debtor/${debtor.id}', extra: debtor);
                                          },
                                        ),
                                        if (debtor.isWarningAutoDelete)
                                          Container(
                                            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: Colors.amber.shade700.withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.warning_amber_rounded,
                                                    size: 20, color: Colors.amber.shade900),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '⚠️ ከ ${debtor.daysUntilDelete} ቀን በኋላ ይሰረዛል',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber.shade900,
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    await ref
                                                        .read(debtRepositoryProvider)
                                                        .keepDebtorRecord(debtor.id);
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text('መዝገቡ በቋሚነት እንዳይሰረዝ ተደረገ። 📌'),
                                                          backgroundColor: Colors.green,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    backgroundColor: Colors.amber.shade700,
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: const Text('አቆይ',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          )
                                        else if (debtor.keepRecord && isSettled)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.bookmark_added, size: 15, color: Colors.green),
                                                SizedBox(width: 4),
                                                Text(
                                                  'መዝገቡ በቋሚነት ተጠብቋል',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/add_debtor');
        },
        icon: const Icon(Icons.add),
        label: const Text('ተበዳሪ ጨምር'),
      ),
    );
  }
}





