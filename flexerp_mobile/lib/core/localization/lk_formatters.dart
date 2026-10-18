import 'package:intl/intl.dart';

/// Sri Lanka Localization utilities (l10n_lk)
/// Handles Sri Lankan Rupee (LKR), statutory taxes (VAT 18%, SSCL 2.5%),
/// NIC numbers, and local contact numbers (+94).
class LkFormatters {
  static const String defaultSymbol = 'Rs.';
  static const String defaultCurrencyCode = 'LKR';

  static String _symbol = defaultSymbol;
  static String _currencyCode = defaultCurrencyCode;

  static NumberFormat _currencyFormat = _buildCurrency(defaultSymbol);
  static NumberFormat _compactCurrencyFormat = _buildCompact(defaultSymbol);

  static NumberFormat _buildCurrency(String symbol) => NumberFormat.currency(
        locale: 'en_LK',
        symbol: '$symbol ',
        decimalDigits: 2,
      );

  static NumberFormat _buildCompact(String symbol) => NumberFormat.compactCurrency(
        locale: 'en_LK',
        symbol: '$symbol ',
        decimalDigits: 1,
      );

  /// Current currency symbol (server-provided via bootstrap, fallback "Rs.").
  static String get currencySymbol => _symbol;

  /// Current ISO currency code (server-provided via bootstrap, fallback "LKR").
  static String get currencyCode => _currencyCode;

  /// Apply the company currency returned by `/flexerp/mobile/bootstrap`.
  /// Null/empty values fall back to Sri Lankan Rupee defaults.
  static void configureCurrency({String? symbol, String? code}) {
    final nextSymbol = (symbol == null || symbol.trim().isEmpty) ? defaultSymbol : symbol.trim();
    final nextCode = (code == null || code.trim().isEmpty) ? defaultCurrencyCode : code.trim();
    if (nextSymbol == _symbol && nextCode == _currencyCode) return;
    _symbol = nextSymbol;
    _currencyCode = nextCode;
    _currencyFormat = _buildCurrency(nextSymbol);
    _compactCurrencyFormat = _buildCompact(nextSymbol);
  }

  /// Restore the default LKR formatting (used on logout).
  static void resetCurrency() => configureCurrency();

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

  static const double ssclRate = 0.025;
  static const double vatRate = 0.18;

  /// Calculates Social Security Contribution Levy (SSCL) - 2.5% of the value.
  static double calculateSscl(double taxableAmount) {
    return taxableAmount * ssclRate;
  }

  /// Calculates Sri Lankan VAT (18%).
  ///
  /// SSCL is levied first and VAT is charged on (value + SSCL), so by default
  /// the VAT base includes SSCL. Pass [includeSscl] = false for SSCL-exempt supplies.
  static double calculateVat(double taxableAmount, {bool includeSscl = true}) {
    final base = includeSscl ? taxableAmount + calculateSscl(taxableAmount) : taxableAmount;
    return base * vatRate;
  }

  /// Total Sri Lankan indirect taxes: SSCL + VAT on (value + SSCL)
  /// = 2.5% + 18% × 1.025 = 20.95% of the value.
  ///
  /// Indicative only — for live POS/invoices always display the server's
  /// `amount_tax` / `amount_total`.
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
