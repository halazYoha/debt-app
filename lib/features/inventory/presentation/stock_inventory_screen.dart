import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/stock_item.dart';
import '../domain/stock_transaction.dart';
import 'inventory_provider.dart';

class StockInventoryScreen extends ConsumerStatefulWidget {
  const StockInventoryScreen({super.key});

  @override
  ConsumerState<StockInventoryScreen> createState() => _StockInventoryScreenState();
}

class _StockInventoryScreenState extends ConsumerState<StockInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── DIALOGS ────────────────────────────────────────────────────────────────

  void _showAddEditDialog({StockItem? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final qtyCtrl = TextEditingController(text: existing?.quantity.toStringAsFixed(2) ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'ኪሎ');
    final priceCtrl = TextEditingController(text: existing?.unitPrice.toStringAsFixed(2) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.add_box_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Text(isEdit ? 'ዕቃ አስተካክል' : 'አዲስ ዕቃ ጨምር',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'የዕቃ ስም (e.g. ስኳር)', Icons.inventory_2_outlined),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _dialogField(qtyCtrl, 'ብዛት', Icons.scale_outlined,
                        numeric: true),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dialogField(unitCtrl, 'መለኪያ', Icons.straighten_outlined, readOnly: true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _dialogField(priceCtrl, 'ዋጋ በ ETB', Icons.attach_money_rounded,
                  numeric: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ሰርዝ'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              final price = double.tryParse(priceCtrl.text) ?? 0;
              final unit = unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'ኪሎ';

              if (name.isEmpty || qty <= 0 || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('እባክዎ ሁሉንም ዝርዝሮች ያስገቡ')),
                );
                return;
              }

              final repo = ref.read(inventoryRepositoryProvider);
              Navigator.pop(ctx);
              try {
                if (isEdit) {
                  await repo.updateStockItem(existing.copyWith(
                    name: name,
                    quantity: qty,
                    unit: unit,
                    unitPrice: price,
                    lastUpdated: DateTime.now(),
                  ));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('ዕቃው በተሳካ ሁኔታ ተዘምኗል ✅'),
                          backgroundColor: Colors.green),
                    );
                  }
                } else {
                  await repo.addStockItem(
                    StockItem(
                      id: '',
                      name: name,
                      quantity: qty,
                      unit: unit,
                      unitPrice: price,
                      lastUpdated: DateTime.now(),
                      lowStockThreshold: 5.0,
                    ),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('$name ተጨምሯል ✅'),
                          backgroundColor: Colors.green),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ስህተት: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded,
                color: Colors.white),
            label: Text(isEdit ? 'አስቀምጥ' : 'ጨምር',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(StockItem item) {
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${item.name} — ዕቃ ጨምር (Restock)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('አሁን ያለ ክምችት: ${item.quantity.toStringAsFixed(2)} ${item.unit}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            _dialogField(qtyCtrl, 'የሚጨምሩት ብዛት (${item.unit})',
                Icons.add_circle_outline_rounded, numeric: true),
            const SizedBox(height: 10),
            _dialogField(priceCtrl, 'አዲስ ዋጋ (ETB) — ባለ ዋጋ ቢቀር ባዶ ይተው',
                Icons.attach_money_rounded, numeric: true),
            const SizedBox(height: 10),
            _dialogField(noteCtrl, 'ማስታወሻ (አስፈላጊ ከሆነ)', Icons.notes_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ሰርዝ'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final added = double.tryParse(qtyCtrl.text) ?? 0;
              if (added <= 0) return;
              final newPrice = double.tryParse(priceCtrl.text);
              Navigator.pop(ctx);
              try {
                final repo = ref.read(inventoryRepositoryProvider);
                // Update price if changed
                final updatedItem = newPrice != null && newPrice > 0
                    ? item.copyWith(unitPrice: newPrice)
                    : item;
                await repo.restockItem(updatedItem, added,
                    note: noteCtrl.text.trim().isNotEmpty
                        ? noteCtrl.text.trim()
                        : null);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${item.name}: +${added.toStringAsFixed(2)} ${item.unit} ተጨምሯል ✅'),
                        backgroundColor: Colors.blue),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ስህተት: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('ዕቃ ጨምር', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeductDialog(StockItem item) {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.remove_shopping_cart_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${item.name} — ዕቃ ሸጥ / ቀነስ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('አሁን ያለ ክምችት: ${item.quantity.toStringAsFixed(2)} ${item.unit}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            _dialogField(qtyCtrl, 'የሚቀነሰው ብዛት (${item.unit})',
                Icons.remove_circle_outline_rounded, numeric: true),
            const SizedBox(height: 10),
            _dialogField(noteCtrl, 'ማስታወሻ (ለምሳሌ: ለደንበኛ ተሸጠ)', Icons.notes_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ሰርዝ'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final deducted = double.tryParse(qtyCtrl.text) ?? 0;
              if (deducted <= 0) return;
              Navigator.pop(ctx);
              try {
                await ref.read(inventoryRepositoryProvider).deductStockQuantity(
                      item.name,
                      deducted,
                      item.unitPrice,
                      note: noteCtrl.text.trim().isNotEmpty
                          ? noteCtrl.text.trim()
                          : 'ዕቃ ተሸጠ',
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${item.name}: -${deducted.toStringAsFixed(2)} ${item.unit} ተቀንሷል ✅'),
                        backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ስህተት: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.remove_rounded, color: Colors.white),
            label: const Text('ቀነስ / ሸጥ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      {bool numeric = false, bool readOnly = false}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('የሱቅ ዕቃዎች እና ሀብት',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded),
            tooltip: 'አዲስ ዕቃ ጨምር',
            onPressed: () => _showAddEditDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'ክምችት'),
            Tab(icon: Icon(Icons.history_rounded), text: 'የዛሬ ታሪክ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: Stock Inventory ─────────────────────────────────────
          inventoryAsync.when(
            data: (items) => _buildInventoryTab(items),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('ስህተት: $e')),
          ),

          // ─── TAB 2: Daily History ───────────────────────────────────────
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('አዲስ ዕቃ', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── INVENTORY TAB ───────────────────────────────────────────────────────────

  Widget _buildInventoryTab(List<StockItem> items) {
    // Summary stats
    final totalValue = items.fold(0.0, (sum, i) => sum + i.totalValue);
    final lowStockItems = items.where((i) => i.isLowStock).length;
    final outOfStock = items.where((i) => i.isOutOfStock).length;

    // Filter by search
    final filtered = items
        .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        // ── Summary Cards ────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              // Total asset value
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('ጠቅላላ የሱቅ ሀብት',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,##0.00').format(totalValue)} ETB',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Sub-stats row
              Row(
                children: [
                  _summaryChip(Icons.category_outlined, '${items.length}', 'ዓይነት ዕቃዎች',
                      Colors.white),
                  const SizedBox(width: 8),
                  _summaryChip(Icons.warning_amber_rounded, '$lowStockItems',
                      'የሚያልቁ', Colors.amber),
                  const SizedBox(width: 8),
                  _summaryChip(Icons.remove_circle_outline, '$outOfStock',
                      'ያለቁ', Colors.red.shade300),
                ],
              ),
            ],
          ),
        ),

        // ── Search Bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'ዕቃ ፈልግ... (e.g. ስኳር)',
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFF10B981)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.green.shade100),
              ),
            ),
          ),
        ),

        // ── Items List ────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.green.shade200),
                      const SizedBox(height: 12),
                      const Text('ምንም ዕቃ አልተጨመረም',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('ከላይ ያለው + ቁልፍን ተጫኑ',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _buildStockCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(StockItem item) {
    Color statusColor = const Color(0xFF10B981);
    String statusText = 'ዕቃ አለ';
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (item.isOutOfStock) {
      statusColor = Colors.red;
      statusText = 'ያለቀ!';
      statusIcon = Icons.remove_circle_outline;
    } else if (item.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'ትንሽ ቀርቷል';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: item.isLowStock || item.isOutOfStock
            ? Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_rounded,
                      color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusText,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') _showAddEditDialog(existing: item);
                    if (val == 'restock') _showRestockDialog(item);
                    if (val == 'deduct') _showDeductDialog(item);
                    if (val == 'delete') _confirmDelete(item);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'restock',
                        child: Row(children: [
                          Icon(Icons.add_shopping_cart_rounded,
                              color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('ዕቃ ጨምር (Restock)'),
                        ])),
                    const PopupMenuItem(
                        value: 'deduct',
                        child: Row(children: [
                          Icon(Icons.remove_shopping_cart_rounded,
                              color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('ዕቃ ሸጥ / ቀነስ'),
                        ])),
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded,
                              color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('አስተካክል'),
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('ሰርዝ', style: TextStyle(color: Colors.red)),
                        ])),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _statPill(
                    '${item.quantity.toStringAsFixed(2)} ${item.unit}',
                    'ክምችት',
                    statusColor),
                const SizedBox(width: 8),
                _statPill(
                    '${item.unitPrice.toStringAsFixed(2)} ETB',
                    'ለ 1 ${item.unit}',
                    const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _statPill(
                    '${NumberFormat('#,##0').format(item.totalValue)} ETB',
                    'ጠቅላላ ዋጋ',
                    const Color(0xFF8B5CF6)),
              ],
            ),

            // Stock meter
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: item.lowStockThreshold > 0
                    ? (item.quantity / (item.lowStockThreshold * 4)).clamp(0.0, 1.0)
                    : 1.0,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ዝቅተኛ ምልክት: ${item.lowStockThreshold.toStringAsFixed(2)} ${item.unit}  •  '
              'ተዘምኗል: ${DateFormat('MMM d, yyyy').format(item.lastUpdated)}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(StockItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ዕቃውን ሰርዝ?'),
        content: Text('"${item.name}" ከዝርዝሩ ይሰረዛል። ይህ ሊቀለበስ አይችልም።'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ሰርዝ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(inventoryRepositoryProvider).deleteStockItem(item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.name} ተሰርዟል')),
                );
              }
            },
            child: const Text('አዎ ሰርዝ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── HISTORY TAB ─────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final todayAsync = ref.watch(todayTransactionsProvider);

    return todayAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 64, color: Colors.green.shade200),
                const SizedBox(height: 12),
                const Text('ዛሬ ምንም ልውውጥ አልተደረገም',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        // Daily summary
        double totalIn = 0;
        double totalOut = 0;
        for (final tx in transactions) {
          if (tx.isStockIn) {
            totalIn += tx.totalValue;
          } else {
            totalOut += tx.totalValue;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Today's summary card
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF0F2447)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.today_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'ዛሬ — ${DateFormat('EEEE, MMM d').format(DateTime.now())}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _historySummaryTile(
                            '${NumberFormat('#,##0').format(totalIn)} ETB',
                            'ዕቃ ገባ (Stock In)',
                            Icons.arrow_downward_rounded,
                            Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _historySummaryTile(
                            '${NumberFormat('#,##0').format(totalOut)} ETB',
                            'ዕቃ ወጣ (Sold)',
                            Icons.arrow_upward_rounded,
                            Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Transaction list
            ...transactions.map((tx) => _buildTransactionCard(tx)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('ስህተት: $e')),
    );
  }

  Widget _historySummaryTile(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(StockTransaction tx) {
    final isIn = tx.isStockIn;
    final color = isIn ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final icon = isIn ? Icons.add_circle_rounded : Icons.remove_circle_rounded;
    final label = isIn ? 'ዕቃ ገባ' : 'ዕቃ ወጣ';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tx.itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${isIn ? '+' : '-'}${tx.quantity.toStringAsFixed(2)} ${tx.unit}  •  '
                  '${tx.unitPrice.toStringAsFixed(2)} ETB/${tx.unit}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (tx.note != null && tx.note!.isNotEmpty)
                  Text(tx.note!,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${NumberFormat('#,##0').format(tx.totalValue)} ETB',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              Text(DateFormat('HH:mm').format(tx.date),
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
