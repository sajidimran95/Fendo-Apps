/// Phone helpers for auth (E.164).
class PhoneNumber {
  PhoneNumber._();

  static const defaultCountryCode = '880';

  /// Normalizes user input to `+{country}…` style.
  ///
  /// If [input] already starts with `+`, that country is kept.
  /// Otherwise [countryCode] (from IP / picker) is applied.
  static String normalize(
    String input, {
    String countryCode = defaultCountryCode,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    var raw = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');
    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? '' : '+$digits';
    }

    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    // Local numbers like 01712… → drop leading 0
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    // Already includes country code digits
    if (digits.startsWith(countryCode)) {
      return '+$digits';
    }
    return '+$countryCode$digits';
  }

  static bool looksValid(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 15;
  }
}
