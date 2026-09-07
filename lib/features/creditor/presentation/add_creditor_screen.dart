import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_error_mapper.dart';
import '../../../core/ethiopian_date.dart';
import '../../../core/ethiopian_date_picker.dart';
import '../../../core/input_validators.dart';
import '../../debt/domain/debtor.dart';
import '../data/creditor_repository.dart';
import '../domain/creditor.dart';

enum CreditorDebtType { items, money }

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

  bool get isValid => nameCtrl.text.trim().isNotEmpty && qty > 0 && price > 0;

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

class AddCreditorScreen extends ConsumerStatefulWidget {
  const AddCreditorScreen({super.key});

  @override
  ConsumerState<AddCreditorScreen> createState() => _AddCreditorScreenState();
}

class _AddCreditorScreenState extends ConsumerState<AddCreditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _moneyAmountController = TextEditingController();
  final _moneyReasonController = TextEditingController();

  CreditorDebtType _debtType = CreditorDebtType.items;
  DateTime _borrowedDate = DateTime.now();
  bool _isLoading = false;

  final List<_ItemRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _addRow();
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
    if (_rows.length <= 1) return;
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
    if (picked != null) {
      setState(() => _borrowedDate = picked);
    }
  }

  Future<void> _saveCreditor() async {
    if (!_formKey.currentState!.validate()) return;

    List<DebtItem> items = [];

    if (_debtType == CreditorDebtType.items) {
      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        if (!row.isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('እባክዎ በዕቃ ቁጥር ${i + 1} ላይ ሁሉንም መረጃዎች ያስገቡ'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        items.add(row.toDebtItem(_borrowedDate));
      }
    } else {
      final amount = double.tryParse(_moneyAmountController.text.trim()) ?? 0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('እባክዎ ትክክለኛ የገንዘብ መጠን ያስገቡ'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final reason = _moneyReasonController.text.trim();
      items.add(DebtItem(
        name: reason.isNotEmpty ? reason : 'ጥሬ ገንዘብ ብድር',
        quantity: 1,
        unit: 'ብር',
        unitPrice: amount,
        date: _borrowedDate,
      ));
    }

    setState(() => _isLoading = true);

    try {
      final creditor = Creditor(
        id: '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        items: items,
        totalPaid: 0,
        borrowedDate: _borrowedDate,
        lastTransactionDate: _borrowedDate,
      );

      await ref.read(creditorRepositoryProvider).addCreditor(creditor);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('የእኔ ዕዳ መዝገብ በተሳካ ሁኔታ ተመዝግቧል! 🎉'),
            backgroundColor: Color(0xFFF59E0B),
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
    final accentColor = const Color(0xFFF59E0B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('አዲስ የእኔ ዕዳ ምዝገባ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: accentColor),
                          const SizedBox(width: 8),
                          const Text(
                            'የአቅራቢ / የሰጭው መረጃ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'የአቅራቢ/የሰጭ ስም *',
                          hintText: 'ምሳሌ፡ አበበ ጅምላ / ካሳሁን',
                          prefixIcon: Icon(Icons.person),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: InputValidators.validateName,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'ስልክ ቁጥር (አስፈላጊ አይደለም)',
                          hintText: '0911223344',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: InputValidators.validatePhone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: accentColor),
                          const SizedBox(width: 8),
                          const Text(
                            'የተበደሩበት ቀን',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                EthiopianDate.formatFull(_borrowedDate),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(Icons.edit_calendar, color: accentColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category_outlined, color: accentColor),
                          const SizedBox(width: 8),
                          const Text(
                            'የዕዳው ዓይነት',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<CreditorDebtType>(
                        segments: const [
                          ButtonSegment(
                            value: CreditorDebtType.items,
                            label: Text('የተበደርኩት ዕቃ'),
                            icon: Icon(Icons.shopping_bag_outlined),
                          ),
                          ButtonSegment(
                            value: CreditorDebtType.money,
                            label: Text('የተበደርኩት ገንዘብ'),
                            icon: Icon(Icons.attach_money),
                          ),
                        ],
                        selected: {_debtType},
                        onSelectionChanged: (set) {
                          setState(() => _debtType = set.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_debtType == CreditorDebtType.items) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.list_alt, color: accentColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'የተበደሯቸው ዕቃዎች',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _addRow,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('ተጨማሪ ዕቃ'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _rows.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 24),
                          itemBuilder: (ctx, idx) {
                            final row = _rows[idx];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: accentColor,
                                      child: Text(
                                        '${idx + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: row.nameCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'የዕቃው ስም *',
                                          hintText: 'ምሳሌ፡ ስኳር / ዘይት',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    if (_rows.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () => _removeRow(idx),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: row.qtyCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'ብዛት *',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: row.unitCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'መለኪያ',
                                          hintText: 'ኪሎ/ካርቶን',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: row.priceCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'ያንዱ ዋጋ *',
                                          suffixText: 'ETB',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                if (row.subtotal > 0) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'ድምር: ${row.subtotal.toStringAsFixed(2)} ETB',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ጠቅላላ የተበደሩት:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_grandTotal.toStringAsFixed(2)} ETB',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money, color: accentColor),
                            const SizedBox(width: 8),
                            const Text(
                              'የተበደሩት ገንዘብ መጠን',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _moneyAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'የገንዘብ መጠን (ETB) *',
                            hintText: '0.00',
                            prefixIcon: const Icon(Icons.monetization_on_outlined),
                            suffixText: 'ETB',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (_debtType != CreditorDebtType.money) return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'እባክዎ የገንዘብ መጠን ያስገቡ';
                            }
                            final val = double.tryParse(v.trim());
                            if (val == null || val <= 0) {
                              return 'ትክክለኛ የገንዘብ መጠን ያስገቡ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _moneyReasonController,
                          decoration: InputDecoration(
                            labelText: 'ምክንያት / ማስታወሻ (አስፈላጊ አይደለም)',
                            hintText: 'ምሳሌ፡ ለሱቅ እቃ መግዣ ጥሬ ገንዘብ',
                            prefixIcon: const Icon(Icons.note_alt_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveCreditor,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'የእኔ ዕዳ መዝግብ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
