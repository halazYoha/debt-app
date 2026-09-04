/// Ethiopian (Ge'ez) calendar conversion utility.
/// Converts Gregorian [DateTime] to Ethiopian date strings in Amharic.
library;

class EthiopianDate {
  final int year;
  final int month;
  final int day;

  const EthiopianDate({required this.year, required this.month, required this.day});

  static const List<String> _monthNames = [
    'መስከረም', // 1
    'ጥቅምት',  // 2
    'ህዳር',   // 3
    'ታህሳስ',  // 4
    'ጥር',    // 5
    'የካቲት',  // 6
    'መጋቢት',  // 7
    'ሚያዝያ',  // 8
    'ግንቦት',  // 9
    'ሰኔ',    // 10
    'ሐምሌ',   // 11
    'ነሐሴ',   // 12
    'ጳጉሜ',   // 13
  ];

  static const List<String> _weekDayNames = [
    'እሑድ',  // Sunday  (weekday % 7 == 0)
    'ሰኞ',   // Monday  (weekday % 7 == 1)
    'ማክሰኞ', // Tuesday (weekday % 7 == 2)
    'ረቡዕ',  // Wednesday
    'ሐሙስ',  // Thursday
    'ዓርብ',  // Friday
    'ቅዳሜ',  // Saturday
  ];

  /// Converts a Gregorian [DateTime] to an [EthiopianDate].
  ///
  /// Algorithm verified against known dates:
  ///   Sep 11, 2025 (Gregorian) = Meskerem 1, 2018 EC
  ///   Sep  2, 2026 (Gregorian) = Nehase    27, 2018 EC  ← today (ET Aug 27)
  static EthiopianDate fromGregorian(DateTime date) {
    // 1. Convert Gregorian date → Julian Day Number (JDN)
    final int jdn = _gregorianToJdn(date.year, date.month, date.day);

    // 2. Ethiopian epoch: Meskerem 1, 1 EC = Julian Aug 29, 8 AD = JDN 1724221
    const int ethEpoch = 1724221;
    int etDays = jdn - ethEpoch;

    // 3. Split into complete 4-year cycles (each = 1461 days)
    int fourYearCycles = etDays ~/ 1461;
    int remainingDays  = etDays % 1461;
    if (remainingDays < 0) {
      fourYearCycles -= 1;
      remainingDays  += 1461;
    }

    int etYear = 4 * fourYearCycles;

    // 4. Within a 4-year cycle the leap year is the THIRD year (year % 4 == 3).
    //    Day layout inside cycle:
    //      Year 1 (mod=1): days   0 –  364  →  365 days
    //      Year 2 (mod=2): days 365 –  729  →  365 days
    //      Year 3 (mod=3): days 730 – 1095  →  366 days  (LEAP)
    //      Year 4 (mod=0): days 1096– 1460  →  365 days
    if (remainingDays < 365) {
      etYear += 1;
      // remainingDays unchanged — position within year 1
    } else if (remainingDays < 730) {
      etYear         += 2;
      remainingDays  -= 365;
    } else if (remainingDays < 1096) {
      etYear         += 3;
      remainingDays  -= 730;
    } else {
      etYear         += 4;
      remainingDays  -= 1096;
    }

    // 5. Each Ethiopian month has exactly 30 days (month 13 has 5 or 6)
    int etMonth = remainingDays ~/ 30 + 1;
    int etDay   = remainingDays % 30 + 1;

    if (etMonth > 13) etMonth = 13;

    return EthiopianDate(year: etYear, month: etMonth, day: etDay);
  }

  static int _gregorianToJdn(int year, int month, int day) {
    final int a = (14 - month) ~/ 12;
    final int y = year + 4800 - a;
    final int m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  String get monthName => _monthNames[(month - 1).clamp(0, 12)];

  /// Full format: "ሰኞ, ነሐሴ 27 2018 ዓ.ም"
  static String formatFull(DateTime date) {
    final eth     = fromGregorian(date);
    final weekday = _weekDayNames[date.weekday % 7];
    return '$weekday, ${eth.monthName} ${eth.day} ${eth.year} ዓ.ም';
  }

  /// Short format: "ነሐሴ 27, 2018"
  static String formatShort(DateTime date) {
    final eth = fromGregorian(date);
    return '${eth.monthName} ${eth.day}, ${eth.year}';
  }
}
