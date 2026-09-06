import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_error_mapper.dart';
import '../../../core/ethiopian_date.dart';
import '../../../core/ethiopian_date_picker.dart';
import '../../../core/input_validators.dart';
import '../domain/debtor.dart';
import '../data/debt_repository.dart';

enum DebtType { items, money }

// ─── Editable item row state ──────────────────────────────────────────────────
class _ItemRow {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;

  _ItemRow()
      : nameCtrl = TextEditingController(),
        qtyCtrl = TextEditingController(),
        unitCtrl = TextEditingController(text: 'ኪሎ'),
        priceCtrl = TextEditingController();

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get price => double.tryParse(priceCtrl.text) ?? 0;
  double get subtotal => qty * price;

  bool get isValid =>
      nameCtrl.text.trim().isNotEmpty && qty > 0 && price > 0;

  DebtItem toDebtItem([DateTime? date]) => DebtItem(
        name: nameCtrl.text.trim(),
        quantity: qty,
        unit: unitCtrl.text.trim(),
        unitPrice: price,
        date: date,
      );

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AddDebtorScreen extends ConsumerStatefulWidget {
  const AddDebtorScreen({super.key});

  @override
  ConsumerState<AddDebtorScreen> createState() => _AddDebtorScreenState();
}

class _AddDebtorScreenState extends ConsumerState<AddDebtorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _moneyAmountController = TextEditingController();
  final _moneyReasonController = TextEditingController();

  DebtType _debtType = DebtType.items;
  DateTime _borrowedDate = DateTime.now();
  bool _isLoading = false;

  final List<_ItemRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _addRow(); // start with one empty row
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _moneyAmountController.dispose();
    _moneyReasonController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_ItemRow()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return; // keep at least one row
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  double get _grandTotal => _rows.fold(0, (s, r) => s + r.subtotal);

  Future<void> _pickDate() async {
    final picked = await EthiopianDatePickerDialog.show(
      context,
      initialDate: _borrowedDate,
    );
    if (picked != null) setState(() => _borrowedDate = picked);
  }


  Future<void> _saveDebtor() async {
    if (!_formKey.currentState!.validate()) return;

    List<DebtItem> debtItems = [];

    if (_debtType == DebtType.items) {
      final validItems = _rows.where((r) => r.isValid).toList();
      if (validItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('እባክዎ ቢያንስ አንድ ትክክለኛ ዕቃ ያስገቡ'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      debtItems = validItems.map((r) => r.toDebtItem(_borrowedDate)).toList();
    } else {
      final moneyAmount = double.tryParse(_moneyAmountController.text.trim()) ?? 0;
      if (moneyAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('እባክዎ ትክክለኛ የገንዘብ መጠን ያስገቡ'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final reason = _moneyReasonController.text.trim();
      debtItems = [
        DebtItem(
          name: reason.isEmpty ? 'ጥሬ ገንዘብ' : 'ጥሬ ገንዘብ ($reason)',
          quantity: 1,
          unit: 'ብር',
          unitPrice: moneyAmount,
          date: _borrowedDate,
        ),
      ];
    }

    setState(() => _isLoading = true);
    try {
      final newDebtor = Debtor(
        id: '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        items: debtItems,
        totalPaid: 0,
        borrowedDate: _borrowedDate,
        lastTransactionDate: DateTime.now(),
      );
      await ref.read(debtRepositoryProvider).addDebtor(newDebtor);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ተበዳሪ ተጨምሯል! ✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorMapper.toAmharic(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ተበዳሪ ጨምር'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person_add, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('አዲስ ተበዳሪ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text('ሁሉንም ዝርዝሮች በጥንቃቄ ይሙሉ',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Customer Info ────────────────────────────────────────────
              _sectionLabel('የደንበኛ መረጃ'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ሙሉ ስም *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: InputValidators.validateName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'ስልክ ቁጥር (አስፈላጊ አይደለም)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: InputValidators.validatePhone,
              ),

              const SizedBox(height: 24),

              // ── Borrowed Date ────────────────────────────────────────────
              _sectionLabel('የዕዳ ቀን'),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: Color(0xFF6B7280)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('የተበደረበት ቀን',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280))),
                          Text(
                            EthiopianDate.formatFull(_borrowedDate),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Debt Type Selector ──────────────────────────────────────
              _sectionLabel('የብድር ዓይነት ይምረጡ'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _debtType = DebtType.items),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _debtType == DebtType.items
                                ? const Color(0xFF10B981)
                                : theme.cardColor,
                            border: Border.all(
                              color: _debtType == DebtType.items
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFD1D5DB),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                color: _debtType == DebtType.items
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ዕቃ ብድር',
                                style: TextStyle(
                                  color: _debtType == DebtType.items
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _debtType = DebtType.money),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _debtType == DebtType.money
                                ? const Color(0xFFF59E0B)
                                : theme.cardColor,
                            border: Border.all(
                              color: _debtType == DebtType.money
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFD1D5DB),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                color: _debtType == DebtType.money
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ገንዘብ ብድር',
                                style: TextStyle(
                                  color: _debtType == DebtType.money
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              if (_debtType == DebtType.items) ...[
                // ── Items Section ────────────────────────────────────────────
                Row(
                  children: [
                    _sectionLabel('ዕቃዎች (ያበደ)'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('ዕቃ ጨምር'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Column headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 4,
                          child: Text('ዕቃ',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                      SizedBox(width: 6),
                      Expanded(
                          flex: 2,
                          child: Text('ብዛት',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                      SizedBox(width: 6),
                      Expanded(
                          flex: 2,
                          child: Text('መለኪያ',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                      SizedBox(width: 6),
                      Expanded(
                          flex: 3,
                          child: Text('ዋጋ (ETB)',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                      SizedBox(width: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                ...List.generate(_rows.length, (i) => _buildItemRow(i)),
                const SizedBox(height: 12),
                _TotalCard(rows: _rows, grandTotal: _grandTotal),
              ] else ...[
                // ── Money Section ────────────────────────────────────────────
                _sectionLabel('የገንዘብ ብድር ዝርዝር'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _moneyAmountController,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'የተበደረው ገንዘብ መጠን (ብር) *',
                    prefixIcon:
                        const Icon(Icons.attach_money, color: Color(0xFFF59E0B)),
                    suffixText: 'ETB',
                    hintText: '0.00',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _moneyReasonController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'ምክንያት / ማስታወሻ',
                    prefixIcon: const Icon(Icons.note_alt_outlined,
                        color: Color(0xFFF59E0B)),
                    hintText: 'ምሳሌ፡ ለቤት ኪራይ / ለአስቸኳይ ጉዳይ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    'ጥሬ ገንዘብ',
                    'ለትራንስፖርት',
                    'ለአስቸኳይ ጉዳይ',
                    'የቤት ኪራይ',
                    'የንግድ ሥራ',
                  ]
                      .map((preset) => ActionChip(
                            label: Text(preset,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.amber.shade50,
                            onPressed: () {
                              setState(() {
                                _moneyReasonController.text = preset;
                              });
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                _MoneyTotalCard(
                  amount:
                      double.tryParse(_moneyAmountController.text.trim()) ?? 0,
                  reason: _moneyReasonController.text.trim(),
                ),
              ],

              const SizedBox(height: 32),

              // ── Save Button ──────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveDebtor,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isLoading ? 'በማስቀመጥ ላይ...' : 'ተበዳሪ አስቀምጥ',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final row = _rows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Item name
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: row.nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ስኳር',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Quantity
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.qtyCtrl,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '1',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Unit
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.unitCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ኪሎ',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Unit price
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: row.priceCtrl,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '100',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          // Delete row
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 20),
              onPressed: () => _removeRow(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151)));
  }
}

// ─── Live Total Summary Card (Items) ─────────────────────────────────────────
class _TotalCard extends StatelessWidget {
  final List<_ItemRow> rows;
  final double grandTotal;

  const _TotalCard({required this.rows, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0F2D4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text('ድምር ስሌት',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          // Per-item breakdown
          ...rows.where((r) => r.subtotal > 0).map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r.qty} ${r.unitCtrl.text.trim()} ${r.nameCtrl.text.trim()}',
                        style:
                            const TextStyle(color: Colors.white60, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '× ${r.price.toStringAsFixed(0)}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '= ${r.subtotal.toStringAsFixed(0)} ETB',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
          if (rows.any((r) => r.subtotal > 0)) ...[
            const Divider(color: Colors.white24, height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ጠቅላላ ብድር',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(
                '${grandTotal.toStringAsFixed(2)} ETB',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Live Total Summary Card (Money Loan) ───────────────────────────────────
class _MoneyTotalCard extends StatelessWidget {
  final double amount;
  final String reason;

  const _MoneyTotalCard({required this.amount, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB45309), Color(0xFF78350F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text('የገንዘብ ብድር ማጠቃለያ',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ምክንያት:',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              Text(
                reason.isEmpty ? 'ጥሬ ገንዘብ' : reason,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ጠቅላላ የተበደረው ገንዘብ',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text(
                '${amount.toStringAsFixed(2)} ETB',
                style: const TextStyle(
                  color: Color(0xFFFCD34D),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

