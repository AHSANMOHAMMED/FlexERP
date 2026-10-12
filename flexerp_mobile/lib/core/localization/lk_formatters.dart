import 'package:intl/intl.dart';

/// Sri Lanka Localization utilities (l10n_lk)
/// Handles Sri Lankan Rupee (LKR), statutory taxes (VAT 18%, SSCL 2.5%),
/// NIC numbers, and local contact numbers (+94).
class LkFormatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_LK',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  static final NumberFormat _compactCurrencyFormat = NumberFormat.compactCurrency(
    locale: 'en_LK',
    symbol: 'Rs. ',
    decimalDigits: 1,
  );

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Formats amount into Sri Lankan Rupees (e.g., "Rs. 142,500.00")
  static String formatLkr(double amount) {
    return _currencyFormat.format(amount);
  }

  /// Compact format for dashboard KPI cards (e.g. "Rs. 1.4M")
  static String formatLkrCompact(double amount) {
    return _compactCurrencyFormat.format(amount);
  }

  /// Formats date for ERP views
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Formats date & time for attendance logs and order timestamps
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Calculates Sri Lankan Value Added Tax (VAT) - Standard 18%
  static double calculateVat(double taxableAmount) {
    return taxableAmount * 0.18;
  }

  /// Calculates Social Security Contribution Levy (SSCL) - 2.5%
  static double calculateSscl(double taxableAmount) {
    return taxableAmount * 0.025;
  }

  /// Calculates Total Sri Lankan taxes (VAT + SSCL = 20.5%)
  static double calculateTotalTaxes(double taxableAmount) {
    return calculateVat(taxableAmount) + calculateSscl(taxableAmount);
  }

  /// Formats Sri Lankan phone number to standard mobile format
  static String formatLkPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('94') && clean.length == 11) {
      return '+94 ${clean.substring(2, 4)} ${clean.substring(4, 7)} ${clean.substring(7)}';
    } else if (clean.startsWith('0') && clean.length == 10) {
      return '+94 ${clean.substring(1, 3)} ${clean.substring(3, 6)} ${clean.substring(6)}';
    }
    return phone;
  }
}
