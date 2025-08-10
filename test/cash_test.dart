import 'package:test/test.dart';
import 'package:cash/src/cash_base.dart';
import 'package:cash/src/currencies/currencies.dart';
import 'package:cash/src/currencies/localization.dart';

void main() {
  final usd = Currency.usd;
  final eur = Currency.eur;

  group("Cash", () {
    test("toString returns correct format", () {
      final cash = Cash(10.5, usd);
      expect(cash.toString(), "\$10.50");
    });

    test("convertTo returns correct value", () {
      final cashUsd = Cash(10, usd);
      final cashEur = cashUsd.convertTo(eur);
      expect(cashEur.currency, eur);
      expect(
        cashEur.value,
        closeTo(10 * eur.exchangeRate / usd.exchangeRate, 0.0001),
      );
    });

    test("operator + adds values with same currency", () {
      final a = Cash(5, usd);
      final b = Cash(7, usd);
      final result = a + b;
      expect(result.value, 12);
      expect(result.currency, usd);
    });

    test("operator + adds values with different currencies", () {
      final a = Cash(10, usd);
      final b = Cash(10, eur);
      final result = a + b;
      expect(result.currency, usd);
      expect(
        result.value,
        closeTo(10 + (10 / eur.exchangeRate * usd.exchangeRate), 0.0001),
      );
    });

    test("operator - subtracts values with same currency", () {
      final a = Cash(10, usd);
      final b = Cash(3, usd);
      final result = a - b;
      expect(result.value, 7);
      expect(result.currency, usd);
    });

    test("operator - subtracts values with different currencies", () {
      final a = Cash(10, usd);
      final b = Cash(10, eur);
      final result = a - b;
      expect(result.currency, usd);
      expect(
        result.value,
        closeTo(10 - (10 / eur.exchangeRate * usd.exchangeRate), 0.0001),
      );
    });

    test("operator * multiplies value", () {
      final cash = Cash(5, usd);
      final result = cash * 3;
      expect(result.value, 15);
      expect(result.currency, usd);
    });

    test("operator / divides value", () {
      final cash = Cash(10, usd);
      final result = cash / 2;
      expect(result.value, 5);
      expect(result.currency, usd);
    });

    test("operator / throws on divide by zero", () {
      final cash = Cash(10, usd);
      expect(() => cash / 0, throwsArgumentError);
    });

    test("comparison operators with same currency", () {
      final a = Cash(10, usd);
      final b = Cash(5, usd);
      expect(a > b, isTrue);
      expect(a >= b, isTrue);
      expect(b < a, isTrue);
      expect(b <= a, isTrue);
    });

    test("comparison operators with different currencies", () {
      final a = Cash(10, usd);
      final b = Cash(10, eur);
      expect(a > b, a.value > b.convertTo(usd).value);
      expect(a >= b, a.value >= b.convertTo(usd).value);
      expect(a < b, a.value < b.convertTo(usd).value);
      expect(a <= b, a.value <= b.convertTo(usd).value);
    });

    test("equality operator with same currency", () {
      final a = Cash(10, usd);
      final b = Cash(10, usd);
      expect(a == b, isTrue);
    });

    test("equality operator with different currencies", () {
      final a = Cash(10, usd);
      final b = Cash(10 / usd.exchangeRate * eur.exchangeRate, eur);
      expect(a == b, isTrue);
    });

    test("hashCode is consistent for equal values", () {
      final a = Cash(10, usd);
      final b = Cash(10, usd);
      expect(a.hashCode, b.hashCode);
    });
  });
  group("Currency", () {
    test("should create a Currency with correct code and symbol", () {
      final currency = Currency.usd;
      expect(currency.code, equals('USD'));
      expect(currency.symbol, isNotEmpty);
    });

    test("should compare currencies by code", () {
      final usd1 = Currency.usd;
      final usd2 = Currency.usd;
      final eur = Currency.eur;
      expect(usd1, equals(usd2));
      expect(usd1 == eur, isFalse);
    });

    test("should resolve locale for currency", () {
      final usd = Currency.usd;
      final loc = usd.resolveLocale("en");
      expect(loc.displayName, isNotEmpty);
      expect(loc.displayCountSingular, isNotEmpty);
      expect(loc.displayCountPlural, isNotEmpty);
    });
  });

  group("CurrencyLocalizationContainer", () {
    test("should resolve locale and fallback to en", () {
      final enContainer = CurrencyLocalizationContainer.resolveLocale('en');
      expect(enContainer, isNotNull);
      expect(enContainer!.locale, equals('en'));

      final fallback = CurrencyLocalizationContainer.resolveLocaleFallback(
        "nonexistent",
      );
      expect(fallback.locale, equals('en'));
    });

    test("should access CurrencyLocalization by currency code", () {
      final enContainer = CurrencyLocalizationContainer.resolveLocale('en');
      final usdLoc = enContainer!['usd'];
      expect(usdLoc, isNotNull);
      expect(usdLoc!.displayName, isNotEmpty);
    });

    test("CurrencyLocalization properties", () {
      final loc = CurrencyLocalizationContainer.resolveLocale("en")!["usd"]!;
      expect(loc.displayName, equals("US Dollar"));
      expect(loc.displayCountSingular, loc.displayName);
      expect(loc.displayCountPlural, loc.displayName);
      expect(loc.hasDisplayCountSingular, isFalse);
      expect(loc.hasDisplayCountPlural, isFalse);
    });
  });
}
