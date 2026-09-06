class InputValidators {
  /// Validates a person's name:
  /// - Cannot be empty
  /// - Cannot be purely numeric (e.g. "12345")
  /// - Must contain at least one valid Amharic or English letter
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'እባክዎ የተበዳሪውን ስም ያስገቡ።';
    }
    final trimmed = value.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'ስም ቁጥር ብቻ መሆን አይችልም። እባክዎ ትክክለኛ ስም ያስገቡ።';
    }
    if (!RegExp(r'[\u1200-\u137Fa-zA-Z]').hasMatch(trimmed)) {
      return 'ስም ቢያንስ አንድ ፊደል ማካተት አለበት።';
    }
    return null;
  }

  /// Validates an Ethiopian mobile phone number:
  /// - Optional (can be empty)
  /// - If entered, must match format (e.g. 0911223344, 0712345678, +251911223344, +251712345678)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }
    final cleanPhone = value.trim().replaceAll(RegExp(r'[\s\-]'), '');
    final ethPhoneRegExp = RegExp(r'^(?:\+251|0)?[97]\d{8}$');
    if (!ethPhoneRegExp.hasMatch(cleanPhone)) {
      return 'ትክክለኛ የስልክ ቁጥር ያስገቡ (ምሳሌ፡ 0911223344 ወይም 0711223344)';
    }
    return null;
  }
}
