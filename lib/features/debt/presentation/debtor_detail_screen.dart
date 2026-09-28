import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_error_mapper.dart';
import '../../../core/ethiopian_date.dart';
import '../../../core/ethiopian_date_picker.dart';
import '../../../core/input_validators.dart';
import '../../../core/offline_banner.dart';
import '../domain/debtor.dart';
import '../data/debt_repository.dart';

class DebtorDetailScreen extends ConsumerStatefulWidget {
  final String debtorId;
  final Debtor? initialDebtor;

  const DebtorDetailScreen({
    super.key,
    required this.debtorId,
    this.initialDebtor,
  });

  @override
  ConsumerState<DebtorDetailScreen> createState() =>
      _DebtorDetailScreenState();
}

class _DebtorDetailScreenState extends ConsumerState<DebtorDetailScreen> {
  final _amountController = TextEditingController();
  final _cashAmountController = TextEditingController();
  final _cashNoteController = TextEditingController();
  bool _isLoading = false;

  // ── Ethiopian Banks List ─────────────────────────────────────────────────
  static const List<Map<String, String>> _ethiopianBanks = [
    {'en': 'Commercial Bank of Ethiopia', 'am': 'የኢትዮጵያ ንግድ ባንክ'},
    {'en': 'Awash Bank',                  'am': 'አዋሽ ባንክ'},
    {'en': 'Abay Bank',                   'am': 'አባይ ባንክ'},
    {'en': 'Coffe Bank',                  'am': 'ቡና ባንክ'},
    {'en': 'Dashen Bank',                 'am': 'ዳሽን ባንክ'},
    {'en': 'Abyssinia Bank',              'am': 'አቢሲኒያ ባንክ'},
    {'en': 'Amhara Bank',                 'am': 'አማራ ባንክ'},
    {'en': 'Tsedey Bank',                 'am': 'ጸደይ ባንክ'},
    {'en': 'Tsehay Bank',                 'am': 'ፀሃይ ባንክ'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _cashAmountController.dispose();
    _cashNoteController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ስልክ መደወል አልተቻለም: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // ── Core: Add items to debtor debt ───────────────────────────────────────
  Future<void> _addAdditionalItems(Debtor currentDebtor, List<DebtItem> newItems) async {
    if (newItems.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final updated = Debtor(
        id: currentDebtor.id,
        name: currentDebtor.name,
        phone: currentDebtor.phone,
        items: [...currentDebtor.items, ...newItems],
        repayments: currentDebtor.repayments,
        totalPaid: currentDebtor.totalPaid,
        borrowedDate: currentDebtor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate: null, // Reset settled status if debtor borrows again
        keepRecord: currentDebtor.keepRecord,
      );
      await ref.read(debtRepositoryProvider).updateDebtor(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ተጨማሪ ብድር ተመዝግቧል! ✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
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

  // ── Dialog 1: Add borrowed items dialog ─────────────────────────────────
  void _showAddItemsDialog(Debtor currentDebtor) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _AddItemsDialog(
        onSave: (items) {
          Navigator.pop(dialogCtx);
          _addAdditionalItems(currentDebtor, items);
        },
      ),
    );
  }

  // ── Dialog 2: Add direct cash loan dialog ────────────────────────────────
  void _showAddCashLoanDialog(Debtor currentDebtor) {
    _cashAmountController.clear();
    _cashNoteController.clear();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.payments, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Expanded(child: Text('ተጨማሪ ገንዘብ ብድር')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ተበዳሪው ተጨማሪ ጥሬ ገንዘብ ሲበደር እዚህ ያስገቡ:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await EthiopianDatePickerDialog.show(
                          context,
                          initialDate: selectedDate,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('የተበደረበት ቀን',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                Text(
                                  EthiopianDate.formatShort(selectedDate),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit_calendar,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cashAmountController,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'የተበደረው ገንዘብ መጠን (ETB) *',
                        prefixIcon: const Icon(Icons.attach_money),
                        hintText: '0.00',
                        suffixText: 'ETB',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cashNoteController,
                      decoration: InputDecoration(
                        labelText: 'ማስታወሻ / ምክንያት (አስፈላጊ አይደለም)',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        hintText: 'ምሳሌ፡ ለትራንስፖርት / ጥሬ ገንዘብ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ሰርዝ'),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final amount =
                              double.tryParse(_cashAmountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('እባክዎ ትክክለኛ የገንዘብ መጠን ያስገቡ'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          final note = _cashNoteController.text.trim();
                          final cashItem = DebtItem(
                            name: note.isEmpty ? 'ጥሬ ገንዘብ' : 'ጥሬ ገንዘብ ($note)',
                            quantity: 1,
                            unit: 'ብር',
                            unitPrice: amount,
                            date: selectedDate,
                          );
                          Navigator.pop(dialogContext);
                          _addAdditionalItems(currentDebtor, [cashItem]);
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B)),
                  child: const Text('ገንዘብ ብድር አስቀምጥ'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  // ── Mark fully paid ─────────────────────────────────────────────────────────
  Future<void> _markFullyPaid(Debtor currentDebtor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ሙሉ ዕዳ ተከፍሏል?'),
        content: Text(
          '${currentDebtor.name} ጠቅላላ ዕዳ ${currentDebtor.totalBorrowed.toStringAsFixed(2)} ETB '
          'ሙሉ በሙሉ ከፍሏል ብለው ለምልክት ያቅርቡ?\n\nከ30 ቀን በኋላ ከዝርዝሩ ይወጣሉ።',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ሰርዝ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('አዎ፣ ተከፍሏል'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final remaining = currentDebtor.remainingBalance;
      if (remaining > 0) {
        final finalPayment = RepaymentRecord(
          amount: remaining,
          date: now,
          note: 'ሙሉ ዕዳ ተከፍሏል',
        );
        await ref.read(debtRepositoryProvider).addRepayment(currentDebtor, finalPayment);
      } else {
        // Already fully paid — just update the settled date
        await ref.read(debtRepositoryProvider).updateSettledDate(currentDebtor, now);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ሙሉ ዕዳ ተከፍሏል! 🎉'),
              backgroundColor: Color(0xFF10B981)),
        );
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

  // ── Payment dialog ──────────────────────────────────────────────────────────
  void _showPaymentDialog(Debtor currentDebtor) {
    _amountController.clear();
    bool isSaving = false;
    String? selectedBankEn;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitPayment() async {
              final amount = double.tryParse(_amountController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                      content: Text('ትክክለኛ መጠን ያስገቡ'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              if (amount > currentDebtor.remainingBalance) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                      content: Text('የተሰጠው መጠን ቀሪ ዕዳን አልፏል'),
                      backgroundColor: Colors.orange),
                );
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                final now = DateTime.now();
                final selectedBankAm = _ethiopianBanks
                    .firstWhere((b) => b['en'] == selectedBankEn, orElse: () => {})['am'];

                final newRepayment = RepaymentRecord(
                  amount: amount,
                  date: now,
                  note: (currentDebtor.totalPaid + amount) >= currentDebtor.totalBorrowed
                      ? 'ከፊል/ሙሉ ክፍያ'
                      : 'ከፊል ክፍያ',
                  bankName: selectedBankAm,
                );
                await ref
                    .read(debtRepositoryProvider)
                    .addRepayment(currentDebtor, newRepayment);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                        content: Text('ክፍያ ተመዝግቧል! ✅'),
                        backgroundColor: Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                setDialogState(() => isSaving = false);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(AppErrorMapper.toAmharic(e)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.payment, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('ክፍያ ምዝገባ'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ቀሪ ዕዳ:',
                              style: TextStyle(color: Colors.red)),
                          Text(
                            '${currentDebtor.remainingBalance.toStringAsFixed(2)} ETB',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      autofocus: true,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'የተከፈለ መጠን (ETB)',
                        prefixIcon: const Icon(Icons.attach_money),
                        hintText: '0.00',
                        suffixText: 'ETB',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    // ── Bank Selection Dropdown ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: selectedBankEn,
                          hint: const Row(
                            children: [
                              Icon(Icons.account_balance,
                                  size: 18, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('ባንክ ይምረጡ (አስፈላጊ አይደለም)',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('— ምንም ባንክ —',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14)),
                            ),
                            ..._ethiopianBanks.map((bank) =>
                              DropdownMenuItem<String?>(
                                value: bank['en'],
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_outlined,
                                        size: 16,
                                        color: Color(0xFF10B981)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(bank['am']!,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14)),
                                    ),
                                  ],
                                ),
                              )),
                          ],
                          onChanged: isSaving
                              ? null
                              : (val) =>
                                  setDialogState(() => selectedBankEn = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('ሰርዝ'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('ክፍያ አስቀምጥ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDebtorDialog(Debtor currentDebtor) {
    final editNameController = TextEditingController(text: currentDebtor.name);
    final editPhoneController = TextEditingController(text: currentDebtor.phone);
    final editFormKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveEdit() async {
              if (!editFormKey.currentState!.validate()) return;
              setDialogState(() => isSaving = true);
              try {
                final newName = editNameController.text.trim();
                final newPhone = editPhoneController.text.trim();
                await ref
                    .read(debtRepositoryProvider)
                    .updateDebtorNameAndPhone(currentDebtor.id, newName, newPhone);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('የተበዳሪው መረጃ ተዘምኗል! ✏️'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() => isSaving = false);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(AppErrorMapper.toAmharic(e)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('የተበዳሪ መረጃ ማስተካከያ'),
                ],
              ),
              content: Form(
                key: editFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: editNameController,
                        decoration: const InputDecoration(
                          labelText: 'ተበዳሪ ስም *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: InputValidators.validateName,
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: editPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'ስልክ ቁጥር (አስፈላጊ አይደለም)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: InputValidators.validatePhone,
                        enabled: !isSaving,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('ሰርዝ'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('አስቀምጥ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Edit a repayment dialog ─────────────────────────────────────────────────
  void _showEditRepaymentDialog(
      Debtor debtor, RepaymentRecord record, List<RepaymentRecord> allRepayments) {
    final amtController =
        TextEditingController(text: record.amount.toStringAsFixed(2));
    final noteController =
        TextEditingController(text: record.note ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    String? selectedBankEn = _ethiopianBanks
        .firstWhere((b) => b['am'] == record.bankName, orElse: () => {})['en'];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;
              final newAmount = double.tryParse(amtController.text.trim());
              if (newAmount == null || newAmount <= 0) return;
              setDialogState(() => isSaving = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final selectedBankAm = _ethiopianBanks
                    .firstWhere((b) => b['en'] == selectedBankEn, orElse: () => {})['am'];

                await ref
                    .read(debtRepositoryProvider)
                    .editRepayment(debtor, record, newAmount, noteController.text, allRepayments, newBankName: selectedBankAm);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('ክፍያ ተስተካክሏል! ✅'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } catch (e) {
                setDialogState(() => isSaving = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('ክፍያ አስተካክል'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amtController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'የክፍያ መጠን (ETB) *',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'የክፍያ መጠን ያስገቡ';
                          }
                          final d = double.tryParse(v.trim());
                          if (d == null || d <= 0) {
                            return 'ትክክለኛ መጠን ያስገቡ';
                          }
                          return null;
                        },
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'ማስታወሻ (አስፈላጊ አይደለም)',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 14),
                      // ── Bank Selection Dropdown ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: selectedBankEn,
                            hint: const Row(
                              children: [
                                Icon(Icons.account_balance,
                                    size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('ባንክ ይምረጡ (አስፈላጊ አይደለም)',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 14)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('— ምንም ባንክ —',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 14)),
                              ),
                              ..._ethiopianBanks.map((bank) =>
                                DropdownMenuItem<String?>(
                                  value: bank['en'],
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance_outlined,
                                          size: 16,
                                          color: Color(0xFF10B981)),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(bank['am']!,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14)),
                                      ),
                                    ],
                                  ),
                                )),
                            ],
                            onChanged: isSaving
                                ? null
                                : (val) =>
                                    setDialogState(() => selectedBankEn = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('ሰርዝ'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('አስቀምጥ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Confirm and delete a repayment ──────────────────────────────────────────
  Future<void> _confirmDeleteRepayment(Debtor debtor, RepaymentRecord record, List<RepaymentRecord> allRepayments) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('ክፍያ ሰርዝ'),
          ],
        ),
        content: Text(
          'ይህን የ${record.amount.toStringAsFixed(2)} ETB ክፍያ '
          'እርግጠኛ ሆነው ማጥፋት ይፈልጋሉ?\n\n'
          'ይህ ተግባር ሊቀለበስ አይችልም።',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('አይ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('አዎ፣ ሰርዝ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(debtRepositoryProvider).deleteRepayment(debtor, record, allRepayments);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ክፍያ ተሰርዟል'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Edit a borrowed item / cash loan ─────────────────────────────────────────
  void _showEditDebtItemDialog(Debtor debtor, int itemIndex, DebtItem item) {
    final nameController = TextEditingController(text: item.name);
    final qtyController = TextEditingController(text: item.quantity.toString());
    final unitController = TextEditingController(text: item.unit);
    final priceController = TextEditingController(text: item.unitPrice.toString());
    DateTime selectedDate = item.date ?? debtor.borrowedDate;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => isSaving = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final qty = double.tryParse(qtyController.text.trim()) ?? 1.0;
                final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                final updatedItem = DebtItem(
                  name: nameController.text.trim(),
                  quantity: qty,
                  unit: unitController.text.trim().isEmpty ? 'ብር' : unitController.text.trim(),
                  unitPrice: price,
                  date: selectedDate,
                );

                await ref
                    .read(debtRepositoryProvider)
                    .editDebtItem(debtor, itemIndex, updatedItem);

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('የተበደረው ዕቃ/ገንዘብ ተስተካክሏል! ✏️'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } catch (e) {
                setDialogState(() => isSaving = false);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(AppErrorMapper.toAmharic(e)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Expanded(child: Text('የተበደረውን ዕቃ/ገንዘብ አስተካክል')),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'የዕቃው/ገንዘቡ ስም *',
                          prefixIcon: const Icon(Icons.shopping_bag_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'እባክዎ ስም ያስገቡ';
                          }
                          return null;
                        },
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'ብዛት *',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'ብዛት ያስገቡ';
                                final d = double.tryParse(v.trim());
                                if (d == null || d <= 0) return 'ትክክለኛ ብዛት ያስገቡ';
                                return null;
                              },
                              enabled: !isSaving,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: unitController,
                              decoration: InputDecoration(
                                labelText: 'መለኪያ (ምሳሌ፡ ኪሎ/ብር)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              enabled: !isSaving,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'ያንዱ ዋጋ / የገንዘብ መጠን (ETB) *',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'ዋጋ ያስገቡ';
                          final d = double.tryParse(v.trim());
                          if (d == null || d < 0) return 'ትክክለኛ ዋጋ ያስገቡ';
                          return null;
                        },
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: isSaving
                            ? null
                            : () async {
                                final picked =
                                    await EthiopianDatePickerDialog.show(
                                  context,
                                  initialDate: selectedDate,
                                  title: 'የተበደረበትን ቀን ይምረጡ',
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'ቀን፡ ${EthiopianDate.formatShort(selectedDate)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('ሰርዝ'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('አስቀምጥ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Confirm and delete a borrowed item ──────────────────────────────────────
  Future<void> _confirmDeleteDebtItem(Debtor debtor, int itemIndex, DebtItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('የተበደሩትን ዕቃ/ገንዘብ ሰርዝ')),
          ],
        ),
        content: Text(
          'ይህንን የተበደሩትን ዕቃ/ገንዘብ "${item.name}" (${item.subtotal.toStringAsFixed(2)} ETB) '
          'እርግጠኛ ሆነው ማጥፋት ይፈልጋሉ?\n\n'
          'ጠቅላላ የተበደረው ገንዘብ እና ቀሪ ዕዳ በራስ-ሰር እንደገና ይሰላል።',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('አይ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('አዎ፣ ሰርዝ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(debtRepositoryProvider).deleteDebtItem(debtor, itemIndex);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('የተበደረው ዕቃ/ገንዘብ ተሰርዟል! 🗑️'),
            backgroundColor: Colors.red,
          ),
        );
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
    final debtorAsync = ref.watch(singleDebtorStreamProvider(widget.debtorId));
    final debtor = debtorAsync.value ?? widget.initialDebtor;

    // Watch repayments from the subcollection
    final repaymentsAsync = ref.watch(repaymentsStreamProvider(widget.debtorId));
    final subcollectionRepayments = repaymentsAsync.value ?? [];

    // Always merge both sources:
    // - Legacy: repayments embedded in the debtor document (old data)
    // - Subcollection: new repayments written to the subcollection
    // Deduplicate by checking subcollection ids vs legacy (legacy have no id).
    final legacyRepayments = (debtor?.repayments ?? [])
        .where((r) =>
            r.id.isEmpty &&
            (subcollectionRepayments.isEmpty || r.note != 'የቀደመ ክፍያ'))
        .toList();
    final allRepayments = [...legacyRepayments, ...subcollectionRepayments];
    allRepayments.sort((a, b) => a.date.compareTo(b.date));
    final repayments = allRepayments;

    if (debtor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('መዝገብ አልተገኘም')),
        body: const Center(
          child: Text('ይህ መዝገብ አልተገኘም ወይም ተሰርዟል።'),
        ),
      );
    }
    final isSettled = debtor.isFullyPaid;
    final progress = debtor.totalBorrowed > 0
        ? (debtor.totalPaid / debtor.totalBorrowed).clamp(0.0, 1.0)
        : 0.0;

    // Days remaining until auto-delete (only relevant when settled)
    int? daysUntilDelete;
    if (isSettled && debtor.settledDate != null) {
      final daysSettled =
          DateTime.now().difference(debtor.settledDate!).inDays;
      daysUntilDelete = (30 - daysSettled).clamp(0, 30);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(debtor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, size: 26),
            tooltip: 'መረጃ አርትዕ',
            onPressed: () => _showEditDebtorDialog(debtor),
          ),
          IconButton(
            icon: Icon(
              Icons.call,
              color: debtor.phone.trim().isNotEmpty
                  ? const Color(0xFF10B981)
                  : Colors.grey.shade400,
            ),
            tooltip: debtor.phone.trim().isNotEmpty
                ? 'ደውል (${debtor.phone})'
                : 'ስልክ ቁጥር አልተመዘገበም',
            onPressed: () => _makePhoneCall(debtor.phone),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _showEditDebtorDialog(debtor);
              if (value == 'fully_paid') _markFullyPaid(debtor);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('ስም/ስልክ አስተካክል'),
                  ],
                ),
              ),
              if (!isSettled)
                const PopupMenuItem(
                  value: 'fully_paid',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green),
                      SizedBox(width: 8),
                      Text('ሙሉ ዕዳ ተከፍሏል ምልክት'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: OfflineAwareScaffoldBody(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile Card ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: isSettled
                              ? Colors.green.withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          child: Text(
                            debtor.name.isNotEmpty
                                ? debtor.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 36,
                              color: isSettled
                                  ? Colors.green
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isSettled)
                          const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.green,
                            child: Icon(Icons.check,
                                color: Colors.white, size: 14),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(debtor.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (debtor.phone.isNotEmpty)
                      InkWell(
                        onTap: () => _makePhoneCall(debtor.phone),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone,
                                  size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text(
                                debtor.phone,
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'የተበደረበት: ${EthiopianDate.formatShort(debtor.borrowedDate)}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    if (isSettled) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text('✅ ሙሉ ዕዳ ተከፍሏል',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (debtor.isWarningAutoDelete) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber.shade700
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.amber.shade900),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '⚠️ ይህ መዝገብ ከ ${debtor.daysUntilDelete} ቀን በኋላ በራስ-ሰር ይሰረዛል። መዝገቡ በቋሚነት እንዲቆይ ይፈልጋሉ?',
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(debtRepositoryProvider)
                                      .keepDebtorRecord(debtor.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'መዝገቡ በቋሚነት እንዳይሰረዝ ተደረገ። 📌'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(Icons.bookmark_add, size: 18),
                                label: const Text('መዝገቡን አቆይ'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (debtor.keepRecord) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '📌 መዝገቡ በቋሚነት ተጠብቋል',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ] else if (daysUntilDelete != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          daysUntilDelete == 0
                              ? 'ዛሬ ከዝርዝሩ ይወጣሉ'
                              : 'ከ$daysUntilDelete ቀን በኋላ ከዝርዝሩ ይወጣሉ',
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Action Buttons Section ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _showAddItemsDialog(debtor),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('ዕቃ ብድር',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _showAddCashLoanDialog(debtor),
                    icon: const Icon(Icons.attach_money, size: 18),
                    label: const Text('ገንዘብ ብድር',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isSettled) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _showPaymentDialog(debtor),
                icon: const Icon(Icons.payment),
                label: const Text('ክፍያ ምዝገባ',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _markFullyPaid(debtor),
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.green),
                label: const Text('ሙሉ ዕዳ ተከፍሏል ምልክት',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.green, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text(
                    '🎉 ሁሉም ዕዳ ተከፍሏል! ታማኝ ደንበኛ ናቸው!',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // ── Items Breakdown Card ──────────────────────────────────────
            if (debtor.items.isNotEmpty)
              Builder(
                builder: (context) {
                  // Group items by normalized date (year, month, day)
                  final Map<DateTime, List<MapEntry<int, DebtItem>>> groupedByDate = {};
                  for (final entry in debtor.items.asMap().entries) {
                    final itemDate = entry.value.date ?? debtor.borrowedDate;
                    final dateKey = DateTime(itemDate.year, itemDate.month, itemDate.day);
                    groupedByDate.putIfAbsent(dateKey, () => []).add(entry);
                  }

                  // Sort dates descending (newest first)
                  final sortedDates = groupedByDate.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  final overallTotal = debtor.totalBorrowed;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Text(
                                'የተበደሩ ዕቃዎች እና ጥሬ ገንዘብ ዝርዝር',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          ...sortedDates.map((date) {
                            final dateEntries = groupedByDate[date]!;
                            final formattedDate = EthiopianDate.formatShort(date);
                            final daySubtotal = dateEntries.fold<double>(
                                0.0, (sum, entry) => sum + entry.value.subtotal);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Header + Item Count Tag
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF10B981)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'ቀን፡ $formattedDate',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981)),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${dateEntries.length} ዕቃ',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Item Cards for this Date
                                  ...dateEntries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final isCashLoan = item.unit == 'ብር' || item.name == 'ጥሬ ገንዘብ ብድር' || (item.quantity == 1 && item.unit == 'ብር');

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          // Icon
                                          Icon(
                                            isCashLoan ? Icons.payments_outlined : Icons.shopping_bag_outlined,
                                            size: 20,
                                            color: isCashLoan ? Colors.green : const Color(0xFF10B981),
                                          ),
                                          const SizedBox(width: 12),
                                          // Name + detail
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                                ),
                                                Text(
                                                  isCashLoan ? 'ጥሬ ገንዘብ ብድር' : '${item.quantity} ${item.unit} × ${item.unitPrice.toStringAsFixed(2)} ETB',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Subtotal
                                          Text(
                                            '${item.subtotal.toStringAsFixed(2)} ETB',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(width: 12),
                                          // Actions
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () => _showEditDebtItemDialog(debtor, index, item),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _confirmDeleteDebtItem(debtor, index, item),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Divider(height: 16),
                                  // Subtotal Footer for this Date
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('የቀን ድምር: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                      Text('${daySubtotal.toStringAsFixed(2)} ETB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            );
                          }),

                          const Divider(height: 24, thickness: 1.5),

                          // Grand Total Section across all dates
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.functions,
                                          size: 20,
                                          color: Color(0xFF10B981)),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'ጠቅላላ የሁሉም ቀናት ብድር:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF10B981),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${overallTotal.toStringAsFixed(2)} ETB',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (debtor.items.isNotEmpty) const SizedBox(height: 12),

            // ── Financial Summary Card ────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bar_chart, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text('የዕዳ ሁኔታ',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Remaining Balance — Prominent First ───────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSettled
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.red.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSettled
                              ? Colors.green.withValues(alpha: 0.35)
                              : Colors.red.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ቀሪ ዕዳ',
                            style: TextStyle(
                              fontSize: 13,
                              color: isSettled ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${debtor.remainingBalance.toStringAsFixed(2)} ETB',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: isSettled ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Progress Bar ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('የክፍያ ሂደት',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor:
                            Colors.red.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? Colors.green
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    _summaryRow('ጠቅላላ ብድር',
                        '${debtor.totalBorrowed.toStringAsFixed(2)} ETB'),
                    const Divider(),
                    _summaryRow('ተከፍሏል',
                        '${debtor.totalPaid.toStringAsFixed(2)} ETB',
                        isPositive: true),
                    const Divider(),
                    _summaryRow(
                      'የተበደረበት ቀን',
                      EthiopianDate.formatShort(debtor.borrowedDate),
                      isDate: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Repayment History Card ────────────────────────────────────
            Builder(
              builder: (context) {
                // 1. Create a unified list of events (Borrowings & Payments) to calculate accurate historical balances
                final List<Map<String, dynamic>> events = [];
                
                for (int i = 0; i < debtor.items.length; i++) {
                  final item = debtor.items[i];
                  events.add({
                    'type': 'borrow',
                    'date': item.date ?? debtor.borrowedDate,
                    'amount': item.subtotal,
                    'title': item.name,
                    'originalIndex': i,
                    'item': item,
                  });
                }
                
                for (int i = 0; i < repayments.length; i++) {
                  final r = repayments[i];
                  events.add({
                    'type': 'repayment',
                    'date': r.date,
                    'amount': r.amount,
                    'repayment': r,
                    'originalIndex': i,
                  });
                }
                
                // Sort ascending by date for ledger calculation
                events.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
                
                // Calculate forward running balance
                double runningBal = 0.0;
                for (var e in events) {
                  if (e['type'] == 'borrow') {
                    runningBal += e['amount'] as double;
                  } else {
                    runningBal -= e['amount'] as double;
                  }
                  e['balanceAfter'] = runningBal;
                }
                
                // Now we group by Date (Descending) for display.
                // For the History list, we ONLY want to show repayments (implicit balance).
                final Map<DateTime, List<Map<String, dynamic>>> repaymentDayGroups = {};
                for (var e in events) {
                  if (e['type'] == 'repayment') {
                    final d = e['date'] as DateTime;
                    final dayKey = DateTime(d.year, d.month, d.day);
                    repaymentDayGroups.putIfAbsent(dayKey, () => []).add(e);
                  }
                }
                
                final sortedRepaymentDays = repaymentDayGroups.keys.toList()..sort((a, b) => b.compareTo(a));

                // 2. Build Daily Borrowed Summary (From borrow events)
                // We still want the summary at the top based on all borrow events
                final Map<DateTime, List<Map<String, dynamic>>> borrowDayGroups = {};
                for (var e in events) {
                  if (e['type'] == 'borrow') {
                    final d = e['date'] as DateTime;
                    final dayKey = DateTime(d.year, d.month, d.day);
                    borrowDayGroups.putIfAbsent(dayKey, () => []).add(e);
                  }
                }
                final sortedBorrowDays = borrowDayGroups.keys.toList()..sort((a, b) => b.compareTo(a));

                final List<Widget> dailySummaryWidgets = [];
                for (var day in sortedBorrowDays) {
                  final dayEvents = borrowDayGroups[day]!;
                  final borrowedAmount = dayEvents.fold(0.0, (s, e) => s + (e['amount'] as double));
                  if (borrowedAmount > 0) {
                    dailySummaryWidgets.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ቀን፡ ${EthiopianDate.formatShort(day)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              '+ ${borrowedAmount.toStringAsFixed(2)} ETB',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                            ),
                          ],
                        ),
                      )
                    );
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Borrowed Summary Section
                    if (dailySummaryWidgets.isNotEmpty) ...[
                      Card(
                        elevation: 0,
                        color: Colors.orange.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.summarize_outlined, color: Colors.orange, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'የተጨመሩ ዕዳዎች ማጠቃለያ (በቀን)',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              ...dailySummaryWidgets,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Repayment History Card (Implicit balance)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.history, color: Color(0xFF10B981)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'የክፍያ ታሪክ',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (sortedRepaymentDays.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text(
                                    'እስካሁን ምንም ታሪክ አልተመዘገበም',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              ...sortedRepaymentDays.map((day) {
                                final dayEvents = repaymentDayGroups[day]!..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
                                final formattedDay = EthiopianDate.formatShort(day);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade900.withValues(alpha: 0.4)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Day Header
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 13, color: Color(0xFF10B981)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'ቀን፡ $formattedDay',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      
                                      // Events (Only Repayments)
                                      ...dayEvents.map((ev) {
                                        final amount = ev['amount'] as double;
                                        final balanceAfter = ev['balanceAfter'] as double;
                                        final time = ev['date'] as DateTime;
                                        final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                                        
                                        return Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    margin: const EdgeInsets.only(top: 2),
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withValues(alpha: 0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      size: 12,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          '+ ${amount.toStringAsFixed(2)} ETB (ክፍያ)',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.green,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        if (ev['repayment'].note != null && (ev['repayment'].note as String).isNotEmpty) ...[
                                                          const SizedBox(height: 2),
                                                          Text(ev['repayment'].note, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(formattedTime, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          InkWell(
                                                            onTap: () => _showEditRepaymentDialog(debtor, ev['repayment'], repayments),
                                                            child: const Padding(
                                                              padding: EdgeInsets.all(4),
                                                              child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                                                            ),
                                                          ),
                                                          InkWell(
                                                            onTap: () => _confirmDeleteRepayment(debtor, ev['repayment'], repayments),
                                                            child: const Padding(
                                                              padding: EdgeInsets.all(4),
                                                              child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  )
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              // Balance After
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: balanceAfter <= 0 ? Colors.green.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      balanceAfter <= 0 ? Icons.check_circle_outline : Icons.account_balance_wallet_outlined,
                                                      size: 13,
                                                      color: balanceAfter <= 0 ? Colors.green : Colors.grey[700],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        balanceAfter <= 0 ? 'ዕዳ ሙሉ በሙሉ ተከፍሏል!' : 'ቀሪ ዕዳ ከክፍያ በኋላ:',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: balanceAfter <= 0 ? Colors.green : Colors.grey[800],
                                                        ),
                                                      ),
                                                    ),
                                                    if (balanceAfter > 0)
                                                      Text(
                                                        '${balanceAfter.toStringAsFixed(2)} ETB',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.grey[800],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ጠቅላላ የተከፈለ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    '${debtor.totalPaid.toStringAsFixed(2)} ETB',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),


          ],
        ),
      ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isPositive = false,
    bool isNegative = false,
    bool isLarge = false,
    bool isDate = false,
  }) {
    Color textColor = Colors.black87;
    if (isPositive) textColor = Colors.green;
    if (isNegative) textColor = Colors.red;
    if (isDate) textColor = Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isLarge ? 16 : 14, color: Colors.grey[700])),
          Text(value,
              style: TextStyle(
                  fontSize: isLarge ? 18 : 14,
                  fontWeight:
                      isLarge ? FontWeight.bold : FontWeight.w500,
                  color: textColor)),
        ],
      ),
    );
  }
}

// ── Add Items Dialog Widget ───────────────────────────────────────────────────
class _AddItemsDialog extends StatefulWidget {
  final Function(List<DebtItem>) onSave;
  const _AddItemsDialog({required this.onSave});

  @override
  State<_AddItemsDialog> createState() => _AddItemsDialogState();
}

class _AddItemsDialogState extends State<_AddItemsDialog> {
  final List<_AddItemRow> _rows = [];
  DateTime _itemsDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _rows.add(_AddItemRow());
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_AddItemRow()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final r = _rows.removeAt(index);
    r.dispose();
    setState(() {});
  }

  double get _grandTotal => _rows.fold(0, (s, r) => s + r.subtotal);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.add_shopping_cart, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('ተጨማሪ ዕቃ ብድር',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ተበዳሪው በሁለተኛውም ሆነ በሌላ ቀን የወሰዳቸውን ዕቃዎች ይጨምሩ:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await EthiopianDatePickerDialog.show(
                    context,
                    initialDate: _itemsDate,
                  );
                  if (picked != null) {
                    setState(() => _itemsDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('የዕቃ መውሰጃ ቀን',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          Text(
                            EthiopianDate.formatShort(_itemsDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Column Headers (same as first-time borrowing screen)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text('ዕቃ',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 4),
                    Expanded(
                        flex: 2,
                        child: Text('ብዛት',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 4),
                    Expanded(
                        flex: 2,
                        child: Text('መለኪያ',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 4),
                    Expanded(
                        flex: 3,
                        child: Text('ዋጋ (ETB)',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 28),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Item rows matching first-time borrowing layout
              ...List.generate(_rows.length, (i) {
                final row = _rows[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Item Name
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: row.nameCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'ስኳር',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Quantity
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.qtyCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: '1',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Unit
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.unitCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'ኪሎ',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Unit Price
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: row.priceCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: '100',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 18),
                          onPressed: () => _removeRow(i),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('ዕቃ ጨምር'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6)),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ተጨማሪ ብድር ድምር:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${_grandTotal.toStringAsFixed(2)} ETB',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF3B82F6)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ሰርዝ'),
        ),
        ElevatedButton(
          onPressed: _grandTotal <= 0
              ? null
              : () {
                  final validItems = _rows
                      .where((r) => r.isValid)
                      .map((r) => r.toDebtItem(_itemsDate))
                      .toList();
                  if (validItems.isNotEmpty) {
                    widget.onSave(validItems);
                  }
                },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6)),
          child: const Text('ዕቃ ብድር አስቀምጥ'),
        ),
      ],
    );
  }
}

class _AddItemRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final unitCtrl = TextEditingController(text: 'ኪሎ');
  final priceCtrl = TextEditingController();

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get price => double.tryParse(priceCtrl.text) ?? 0;
  double get subtotal => qty * price;
  bool get isValid => nameCtrl.text.trim().isNotEmpty && qty > 0 && price > 0;

  DebtItem toDebtItem([DateTime? date]) => DebtItem(
        name: nameCtrl.text.trim(),
        quantity: qty,
        unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'ኪሎ',
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

