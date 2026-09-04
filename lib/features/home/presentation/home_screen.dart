import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../debt/data/debt_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/ethiopian_date.dart';
import '../../../core/ethiopian_date_picker.dart';

enum DebtorFilter { all, over50k }

enum DateFilterType { all, today, thisWeek, thisMonth, oneYearAgo, customRange }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  DebtorFilter _selectedFilter = DebtorFilter.all;
  DateFilterType _dateFilter = DateFilterType.all;
  DateTimeRange? _customRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final fromDate = await EthiopianDatePickerDialog.show(
      context,
      initialDate: _customRange?.start ?? DateTime.now(),
    );
    if (fromDate == null || !mounted) return;

    final toDate = await EthiopianDatePickerDialog.show(
      context,
      initialDate: _customRange?.end ?? DateTime.now(),
    );
    if (toDate == null || !mounted) return;

    setState(() {
      _customRange = DateTimeRange(
        start: fromDate.isBefore(toDate) ? fromDate : toDate,
        end: toDate.isAfter(fromDate) ? toDate : fromDate,
      );
      _dateFilter = DateFilterType.customRange;
    });
  }

  @override
  Widget build(BuildContext context) {
    final debtorsAsync = ref.watch(debtorsProvider);

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
              case DateFilterType.customRange:
                if (_customRange != null) {
                  final start = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
                  final end = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
                  if (bDate.isBefore(start) || bDate.isAfter(end)) return false;
                }
                break;
              case DateFilterType.all:
                break;
            }

            // 3. Search Query Filter
            final query = _searchQuery.toLowerCase();
            if (query.isEmpty) return true;
            return debtor.name.toLowerCase().contains(query) || debtor.phone.contains(query);
          }).toList();
          
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Theme.of(context).primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text(
                            'ጠቅላላ ያልተከፈለ ዕዳ',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${totalOwed.toStringAsFixed(2)} ETB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              ),
              // ── Select Buttons for Debtors Filter ──────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedFilter == DebtorFilter.all
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedFilter == DebtorFilter.all
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'ሁሉም ተበዳሪዎች (${allDebtors.length})',
                                  style: TextStyle(
                                    color: _selectedFilter == DebtorFilter.all
                                        ? Colors.white
                                        : Colors.grey.shade800,
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedFilter == DebtorFilter.over50k
                                    ? const Color(0xFFD97706)
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedFilter == DebtorFilter.over50k
                                      ? const Color(0xFFD97706)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'ከ 50,000 ብር በላይ ($over50kCount)',
                                  style: TextStyle(
                                    color: _selectedFilter == DebtorFilter.over50k
                                        ? Colors.white
                                        : Colors.grey.shade800,
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
              ),

              // ── Date Filters Row ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(
                          Icons.date_range,
                          size: 16,
                          color: _dateFilter == DateFilterType.customRange
                              ? Colors.white
                              : Theme.of(context).primaryColor,
                        ),
                        label: Text(
                          _dateFilter == DateFilterType.customRange && _customRange != null
                              ? '${EthiopianDate.formatShort(_customRange!.start)} - ${EthiopianDate.formatShort(_customRange!.end)}'
                              : '📅 የቀን ክልል (ከ... እስከ...)',
                          style: TextStyle(
                            color: _dateFilter == DateFilterType.customRange ? Colors.white : Colors.black87,
                            fontWeight: _dateFilter == DateFilterType.customRange ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: _dateFilter == DateFilterType.customRange
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).cardColor,
                        side: BorderSide(
                          color: _dateFilter == DateFilterType.customRange
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                        ),
                        onPressed: _pickCustomRange,
                      ),
                    ],
                  ),
                ),
              ),

              // Active Date Filter Reset Banner
              if (_dateFilter != DateFilterType.all)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_outlined, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dateFilter == DateFilterType.customRange && _customRange != null
                                  ? 'የቀን ክልል: ${EthiopianDate.formatShort(_customRange!.start)} - ${EthiopianDate.formatShort(_customRange!.end)}'
                                  : 'የቀን ማጣሪያ ነቅቷል',
                              style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() {
                              _dateFilter = DateFilterType.all;
                              _customRange = null;
                            }),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text('✕ አፅዳ', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'ተበዳሪዎች',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (allDebtors.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('ተበዳሪ አልተጨመረም። ➕ ተበዳሪ ጨምር ይጫኑ!'),
                    ),
                  ),
                )
              else if (_selectedFilter == DebtorFilter.over50k && filteredDebtors.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('ከ 50,000 ብር በላይ የተበደረ ደንበኛ የለም።'),
                    ),
                  ),
                )
              else if (filteredDebtors.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('ለተመረጠው የቀን ማጣሪያ ወይም ፍለጋ ውጤት አልተገኘም።'),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final debtor = filteredDebtors[index];
                      final isSettled = debtor.remainingBalance <= 0;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                      fontSize: 16,
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
                    childCount: filteredDebtors.length,
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
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
      ),
      onSelected: (_) {
        setState(() {
          _dateFilter = type;
          if (type != DateFilterType.customRange) _customRange = null;
        });
      },
    );
  }
}


