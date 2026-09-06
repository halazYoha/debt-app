import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_error_mapper.dart';
import '../../../core/ethiopian_date.dart';
import '../../../core/ethiopian_date_picker.dart';
import '../domain/debtor.dart';
import '../data/debt_repository.dart';

class DebtorDetailScreen extends ConsumerStatefulWidget {
  final Debtor debtor;
  const DebtorDetailScreen({super.key, required this.debtor});

  @override
  ConsumerState<DebtorDetailScreen> createState() =>
      _DebtorDetailScreenState();
}

class _DebtorDetailScreenState extends ConsumerState<DebtorDetailScreen> {
  final _amountController = TextEditingController();
  final _cashAmountController = TextEditingController();
  final _cashNoteController = TextEditingController();
  bool _isLoading = false;

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
  Future<void> _addAdditionalItems(List<DebtItem> newItems) async {
    if (newItems.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final updated = Debtor(
        id: widget.debtor.id,
        name: widget.debtor.name,
        phone: widget.debtor.phone,
        items: [...widget.debtor.items, ...newItems],
        repayments: widget.debtor.repayments,
        totalPaid: widget.debtor.totalPaid,
        borrowedDate: widget.debtor.borrowedDate,
        lastTransactionDate: DateTime.now(),
        settledDate: null, // Reset settled status if debtor borrows again
      );
      await ref.read(debtRepositoryProvider).updateDebtor(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ተጨማሪ ብድር ተመዝግቧል! ✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
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
  void _showAddItemsDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => _AddItemsDialog(
        onSave: (items) {
          Navigator.pop(dialogCtx);
          _addAdditionalItems(items);
        },
      ),
    );
  }

  // ── Dialog 2: Add direct cash loan dialog ────────────────────────────────
  void _showAddCashLoanDialog() {
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
                  Text('ተጨማሪ ገንዘብ ብድር'),
                ],
              ),
              content: Column(
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
                          _addAdditionalItems([cashItem]);
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

  // ── Record partial payment ──────────────────────────────────────────────────
  Future<void> _recordPayment(
      BuildContext dialogContext, double amount) async {
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ትክክለኛ መጠን ያስገቡ'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (amount > widget.debtor.remainingBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('የተሰጠው መጠን ቀሪ ዕዳን አልፏል'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final newTotalPaid = widget.debtor.totalPaid + amount;
      final isNowSettled = newTotalPaid >= widget.debtor.totalBorrowed;
      final newRepayment = RepaymentRecord(
        amount: amount,
        date: now,
        note: isNowSettled ? 'ከፊል/ሙሉ ክፍያ' : 'ከፊል ክፍያ',
      );
      final updatedRepayments = [...widget.debtor.repayments, newRepayment];

      final updated = Debtor(
        id: widget.debtor.id,
        name: widget.debtor.name,
        phone: widget.debtor.phone,
        items: widget.debtor.items,
        repayments: updatedRepayments,
        totalPaid: newTotalPaid,
        borrowedDate: widget.debtor.borrowedDate,
        lastTransactionDate: now,
        settledDate: isNowSettled ? now : widget.debtor.settledDate,
      );
      await ref.read(debtRepositoryProvider).updateDebtor(updated);
      if (mounted) {
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ክፍያ ተመዝግቧል! ✅'),
              backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context);
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

  // ── Mark fully paid ─────────────────────────────────────────────────────────
  Future<void> _markFullyPaid() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ሙሉ ዕዳ ተከፍሏል?'),
        content: Text(
          '${widget.debtor.name} ጠቅላላ ዕዳ ${widget.debtor.totalBorrowed.toStringAsFixed(2)} ETB '
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
      final remaining = widget.debtor.remainingBalance;
      final updatedRepayments =
          List<RepaymentRecord>.from(widget.debtor.repayments);
      if (remaining > 0) {
        updatedRepayments.add(
          RepaymentRecord(
            amount: remaining,
            date: now,
            note: 'ሙሉ ዕዳ ተከፍሏል',
          ),
        );
      }
      final updated = Debtor(
        id: widget.debtor.id,
        name: widget.debtor.name,
        phone: widget.debtor.phone,
        items: widget.debtor.items,
        repayments: updatedRepayments,
        totalPaid: widget.debtor.totalBorrowed, // fully paid
        borrowedDate: widget.debtor.borrowedDate,
        lastTransactionDate: now,
        settledDate: now, // ← triggers auto-delete after 30 days
      );
      await ref.read(debtRepositoryProvider).updateDebtor(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ሙሉ ዕዳ ተከፍሏል! 🎉'),
              backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context);
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
  void _showPaymentDialog() {
    _amountController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) {
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
          content: Column(
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
                      '${widget.debtor.remainingBalance.toStringAsFixed(2)} ETB',
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
            ],
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
                          double.tryParse(_amountController.text) ?? 0;
                      _recordPayment(dialogContext, amount);
                    },
              child: _isLoading
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
  }

  @override
  Widget build(BuildContext context) {
    final debtor = widget.debtor;
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
          if (!isSettled)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'fully_paid') _markFullyPaid();
              },
              itemBuilder: (_) => [
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
      body: SingleChildScrollView(
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

            // ── Items Breakdown Card ──────────────────────────────────────
            if (debtor.items.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              color: Color(0xFF10B981)),
                          SizedBox(width: 8),
                          Text('የተበደሩ ዕቃዎች እና ጥሬ ገንዘብ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Table header
                      const Row(
                        children: [
                          Expanded(
                              flex: 4,
                              child: Text('ዕቃ / ገንዘብ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600))),
                          Expanded(
                              flex: 3,
                              child: Text('ብዛት × ዋጋ',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey))),
                          Expanded(
                              flex: 3,
                              child: Text('ድምር',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey))),
                        ],
                      ),
                      const Divider(),
                      ...debtor.items.map((item) {
                        final itemDate = item.date ?? debtor.borrowedDate;
                        final formattedDate =
                            EthiopianDate.formatShort(itemDate);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 11, color: Colors.grey),
                                        const SizedBox(width: 3),
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${item.quantity} ${item.unit} × ${item.unitPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${item.subtotal.toStringAsFixed(0)} ETB',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ጠቅላላ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            '${debtor.totalBorrowed.toStringAsFixed(2)} ETB',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('የክፍያ ሂደት',
                                style: TextStyle(color: Colors.grey)),
                            Text('${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.red.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0
                                  ? Colors.green
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _summaryRow('የተበደረበት ቀን',
                        EthiopianDate.formatShort(debtor.borrowedDate),
                        isDate: true),
                    const Divider(),
                    _summaryRow('ጠቅላላ ብድር',
                        '${debtor.totalBorrowed.toStringAsFixed(2)} ETB'),
                    const Divider(),
                    _summaryRow('ተከፍሏል',
                        '${debtor.totalPaid.toStringAsFixed(2)} ETB',
                        isPositive: true),
                    const Divider(),
                    _summaryRow(
                      'ቀሪ ዕዳ',
                      '${debtor.remainingBalance.toStringAsFixed(2)} ETB',
                      isLarge: true,
                      isNegative: !isSettled,
                      isPositive: isSettled,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Repayment History Card ────────────────────────────────────
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
                        Text(
                          'የክፍያ ታሪክ',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (debtor.repayments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            'እስካሁን ምንም ክፍያ አልተመዘገበም',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else ...[
                      // Table header
                      const Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'የክፍያ መጠን',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Text(
                              'የተከፈለበት ቀን',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      ...debtor.repayments.map((repayment) {
                        final formattedTime =
                            '${repayment.date.hour.toString().padLeft(2, '0')}:${repayment.date.minute.toString().padLeft(2, '0')}';
                        final dateStr =
                            '${EthiopianDate.formatShort(repayment.date)} ($formattedTime)';
                        final hasNote = repayment.note != null &&
                            repayment.note!.isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          size: 16, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+ ${repayment.amount.toStringAsFixed(2)} ETB',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              if (hasNote)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 22, top: 2),
                                  child: Text(
                                    'ማስታወሻ: ${repayment.note}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ጠቅላላ የተከፈለ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Action Buttons Section ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showAddItemsDialog,
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
                    onPressed: _isLoading ? null : _showAddCashLoanDialog,
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
                onPressed: _isLoading ? null : _showPaymentDialog,
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
                onPressed: _isLoading ? null : _markFullyPaid,
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
          ],
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

