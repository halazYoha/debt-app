import 'package:flutter/material.dart';
import 'ethiopian_date.dart';

/// An Amharic Ethiopian Date Picker dialog.
/// Allows shopkeepers to pick dates in Ethiopian Months & Years easily.
class EthiopianDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final String? title;

  const EthiopianDatePickerDialog({
    super.key,
    required this.initialDate,
    this.title,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    String? title,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => EthiopianDatePickerDialog(
        initialDate: initialDate ?? DateTime.now(),
        title: title,
      ),
    );
  }

  @override
  State<EthiopianDatePickerDialog> createState() => _EthiopianDatePickerDialogState();
}

class _EthiopianDatePickerDialogState extends State<EthiopianDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  static const List<String> _monthNames = [
    'መስከረም',
    'ጥቅምት',
    'ህዳር',
    'ታህሳስ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜ',
  ];

  @override
  void initState() {
    super.initState();
    final eth = EthiopianDate.fromGregorian(widget.initialDate);
    _selectedYear = eth.year;
    _selectedMonth = eth.month;
    _selectedDay = eth.day;
  }

  /// Converts Ethiopian (Year, Month, Day) roughly to Gregorian DateTime for saving
  DateTime _toGregorian(int ethYear, int ethMonth, int ethDay) {
    // Meskerem 1, 1 EC = JDN 1724221
    // Approximate offset: Ethiopian year + 7 or 8 = Gregorian year
    // Calculate total days from Ethiopian Epoch
    int cycles = (ethYear - 1) ~/ 4;
    int yearInCycle = (ethYear - 1) % 4;

    int totalDays = cycles * 1461;
    if (yearInCycle == 1) totalDays += 365;
    if (yearInCycle == 2) totalDays += 730;
    if (yearInCycle == 3) totalDays += 1096;

    totalDays += (ethMonth - 1) * 30 + (ethDay - 1);
    int jdn = 1724221 + totalDays;

    // Convert JDN -> Gregorian DateTime
    int l = jdn + 68569;
    int n = (4 * l) ~/ 146097;
    l = l - (146097 * n + 3) ~/ 4;
    int i = (4000 * (l + 1)) ~/ 1461001;
    l = l - (1461 * i) ~/ 4 + 31;
    int j = (80 * l) ~/ 2447;
    int day = l - (2447 * j) ~/ 80;
    l = j ~/ 11;
    int month = j + 2 - (12 * l);
    int year = 100 * (n - 49) + i + l;

    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) {
    final maxDaysInMonth = _selectedMonth == 13 ? 6 : 30;
    if (_selectedDay > maxDaysInMonth) {
      _selectedDay = maxDaysInMonth;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Text(widget.title ?? 'ቀን ይምረጡ (ዓ.ም)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Dropdown
            const Text('ወር:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: List.generate(13, (index) {
                    final m = index + 1;
                    return DropdownMenuItem(
                      value: m,
                      child: Text('${_monthNames[index]} ($m)'),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMonth = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Day Dropdown
            const Text('ቀን:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedDay,
                  isExpanded: true,
                  items: List.generate(maxDaysInMonth, (index) {
                    final d = index + 1;
                    return DropdownMenuItem(
                      value: d,
                      child: Text('ቀን $d'),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDay = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Year Dropdown
            const Text('ዓመተ ምሕረት (ዓ.ም):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  isExpanded: true,
                  items: List.generate(10, (index) {
                    final y = 2015 + index; // 2015 - 2024 EC
                    return DropdownMenuItem(
                      value: y,
                      child: Text('$y ዓ.ም'),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedYear = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Preview selected date
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'የተመረጠው ቀን: ${_monthNames[_selectedMonth - 1]} $_selectedDay, $_selectedYear ዓ.ም',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ሰርዝ'),
        ),
        ElevatedButton(
          onPressed: () {
            final gregDate = _toGregorian(_selectedYear, _selectedMonth, _selectedDay);
            Navigator.pop(context, gregDate);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          child: const Text('ቀን አስቀምጥ'),
        ),
      ],
    );
  }
}
