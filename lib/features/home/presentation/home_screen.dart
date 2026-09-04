import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../debt/data/debt_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/ethiopian_date.dart';

enum DebtorFilter { all, over50k }

enum DateFilterType { all, today, thisWeek, thisMonth, oneYearAgo }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  DebtorFilter _selectedFilter = DebtorFilter.all;
  DateFilterType _dateFilter = DateFilterType.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtorsAsync = ref.watch(debtorsProvider);
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ዋና ገጽ'),
        actions: [
          IconButton(
            tooltip: 'ውጣ',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: debtorsAsync.when(
        data: (allDebtors) {
          final totalOwed = allDebtors.fold(0.0, (sum, item) => sum + item.remainingBalance);
          final over50kCount = allDebtors.where((d) => d.totalBorrowed > 50000).length;

          final filteredDebtors = allDebtors.where((debtor) {
            // 1. Amount Filter
            if (_selectedFilter == DebtorFilter.over50k && debtor.totalBorrowed <= 50000) {
              return false;
            }

            // 2. Date Filter
            final now = DateTime.now();
            final bDate = debtor.borrowedDate;

            switch (_dateFilter) {
              case DateFilterType.today:
                if (bDate.year != now.year || bDate.month != now.month || bDate.day != now.day) {
                  return false;
                }
                break;
              case DateFilterType.thisWeek:
                final weekAgo = now.subtract(const Duration(days: 7));
                if (bDate.isBefore(weekAgo)) return false;
                break;
              case DateFilterType.thisMonth:
                final nowEth = EthiopianDate.fromGregorian(now);
                final bEth = EthiopianDate.fromGregorian(bDate);
                if (bEth.year != nowEth.year || bEth.month != nowEth.month) return false;
                break;
              case DateFilterType.oneYearAgo:
                final yearAgo = now.subtract(const Duration(days: 365));
                if (bDate.isBefore(yearAgo)) return false;
                break;
              case DateFilterType.all:
                break;
            }

            // 3. Search Query Filter
            final query = _searchQuery.toLowerCase();
            if (query.isEmpty) return true;
            return debtor.name.toLowerCase().contains(query) || debtor.phone.contains(query);
          }).toList();
          
          return Column(
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
                        const Text(
                          'ጠቅላላ ያልተከፈለ ዕዳ',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${totalOwed.toStringAsFixed(2)} ETB',
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

              // ── Quick Date Filters Row ───────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    _dateChip('ሁሉም ቀናት', DateFilterType.all),
                    const SizedBox(width: 8),
                    _dateChip('ዛሬ', DateFilterType.today),
                    const SizedBox(width: 8),
                    _dateChip('በዚህ ሳምንት', DateFilterType.thisWeek),
                    const SizedBox(width: 8),
                    _dateChip('በዚህ ወር', DateFilterType.thisMonth),
                    const SizedBox(width: 8),
                    _dateChip('የ1 ዓመት', DateFilterType.oneYearAgo),
                  ],
                ),
              ),

              // Active Date Filter Reset Banner
              if (_dateFilter != DateFilterType.all)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'የቀን ማጣሪያ ነቅቷል',
                            style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _dateFilter = DateFilterType.all),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Text('✕ አፅዳ', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
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
                                child: Text('ለተመረጠው የቀን ማጣሪያ ወይም ፍለጋ ውጤት አልተገኘም።'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: filteredDebtors.length,
                                itemBuilder: (context, index) {
                                  final debtor = filteredDebtors[index];
                                  final isSettled = debtor.remainingBalance <= 0;
                                  
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: ListTile(
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
                                        debtor.phone.isNotEmpty
                                            ? '${debtor.phone} · ${EthiopianDate.formatShort(debtor.borrowedDate)}'
                                            : EthiopianDate.formatShort(debtor.borrowedDate),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
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
                                  );
                                },
                              ),
              ),
            ],
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

  Widget _dateChip(String label, DateFilterType type) {
    final isSelected = _dateFilter == type;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : onSurfaceColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
      ),
      onSelected: (_) {
        setState(() {
          _dateFilter = type;
        });
      },
    );
  }
}



