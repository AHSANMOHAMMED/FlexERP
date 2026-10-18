import 'package:flutter_test/flutter_test.dart';
import 'package:flexerp_mobile/core/localization/lk_formatters.dart';

void main() {
  tearDown(LkFormatters.resetCurrency);

  group('currency formatting', () {
    test('defaults to Rs. when no server currency is configured', () {
      expect(LkFormatters.currencySymbol, 'Rs.');
      expect(LkFormatters.currencyCode, 'LKR');
      expect(LkFormatters.formatLkr(142500), 'Rs. 142,500.00');
    });

    test('uses the server-provided symbol from bootstrap', () {
      LkFormatters.configureCurrency(symbol: '\$', code: 'USD');
      expect(LkFormatters.formatLkr(1234.5), '\$ 1,234.50');
      expect(LkFormatters.currencyCode, 'USD');
    });

    test('falls back to Rs. for empty / null server values', () {
      LkFormatters.configureCurrency(symbol: '', code: null);
      expect(LkFormatters.currencySymbol, 'Rs.');
      expect(LkFormatters.formatLkr(10), 'Rs. 10.00');
    });
  });

  group('Sri Lanka SSCL / VAT', () {
    test('SSCL is 2.5% of the value', () {
      expect(LkFormatters.calculateSscl(1000), closeTo(25, 1e-9));
    });

    test('VAT 18% is charged on value + SSCL', () {
      // (1000 + 25) * 0.18 = 184.5
      expect(LkFormatters.calculateVat(1000), closeTo(184.5, 1e-9));
      expect(LkFormatters.calculateVat(1000, includeSscl: false), closeTo(180, 1e-9));
    });

    test('total taxes = 20.95% of the value', () {
      expect(LkFormatters.calculateTotalTaxes(1000), closeTo(209.5, 1e-9));
    });
  });

  test('formats LK phone numbers', () {
    expect(LkFormatters.formatLkPhone('0771234567'), '+94 77 123 4567');
    expect(LkFormatters.formatLkPhone('94771234567'), '+94 77 123 4567');
  });
}
