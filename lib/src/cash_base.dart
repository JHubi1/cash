import 'dart:math';

import 'package:cash/src/currencies/currencies.dart';
import 'package:cash/src/currencies/localization.dart';

/// A container class for cash values.
class Cash {
  /// Represents a monetary [value] in a specific [currency].
  double get value => _value / pow(10, currency.exponent);
  final int _value;

  /// The currency associated with this cash [value].
  final Currency currency;

  /// Construct a new [Cash] instance with the given properties.
  ///
  /// The [currency] are stored as-is. [value] is calculated to the number of
  /// decimal places defined by the [Currency.exponent] of [currency].
  ///
  /// You can use [convertTo] to convert this cash value to another currency.
  Cash(double value, this.currency)
    : _value = (value * pow(10, currency.exponent)).round();

  /// Create a string representation of the cash value.
  ///
  /// The string is put together from the currency symbol, or the currency code
  /// if no symbol is available, and the value formatted to two decimal places.
  ///
  /// You may not want to use this method if better ways are available, like
  /// `intl`'s [NumberFormat.currency](https://pub.dev/documentation/intl/latest/intl/NumberFormat/NumberFormat.currency.html).
  @override
  String toString() =>
      "${currency.symbol ?? currency.code}${value.toStringAsFixed(2)}";

  /// Create a string representation of the cash value in a human-readable
  /// format.
  ///
  /// This uses [CurrencyLocalization.displayCountSingular] or
  /// [CurrencyLocalization.displayCountPlural] based on the value.
  ///
  /// It may not be a correct representation in the [locale] though, because
  /// this method simply appends the localized display count to the value.
  ///
  /// Example: "100.00 US Dollar"
  ///
  /// You may not want to use this method if better ways are available, like
  /// `intl`'s [NumberFormat.currency](https://pub.dev/documentation/intl/latest/intl/NumberFormat/NumberFormat.currency.html).
  String toDisplayString(String locale) {
    var container = CurrencyLocalizationContainer.resolveLocaleFallback(locale);
    var localization = container[currency.code]!;
    return "${value.toStringAsFixed(2)} ${(value == 1) ? localization.displayCountSingular : localization.displayCountPlural}";
  }

  /// Converts this cash value to another [targetCurrency].
  ///
  /// This uses the exchange rates to convert the value to the target currency.
  ///
  /// You may want to use [Currency.refetchExchangeRates] before this to ensure
  /// that the exchange rates are up-to-date.
  ///
  /// The values produced by this method are likely not accurate to other
  /// services providing currency conversion. This is hardly avoidable for a
  /// free package.
  ///
  /// If higher accuracy is required, use another API service to fetch the
  /// exchange rates and update the values manually using
  /// [Currency.overwriteExchangeRate].
  Cash convertTo(Currency targetCurrency) {
    if (currency == targetCurrency) return this;
    final usd = value / currency.exchangeRate;
    final convertedValue = usd * targetCurrency.exchangeRate;
    return Cash(convertedValue, targetCurrency);
  }

  Cash operator +(Cash other) {
    if (currency == other.currency) {
      return Cash(value + other.value, currency);
    }
    return Cash(value + other.convertTo(currency).value, currency);
  }

  Cash operator -(Cash other) {
    if (currency == other.currency) {
      return Cash(value - other.value, currency);
    }
    return Cash(value - other.convertTo(currency).value, currency);
  }

  Cash operator *(num multiplier) {
    return Cash(value * multiplier, currency);
  }

  Cash operator /(num divisor) {
    if (divisor == 0) throw ArgumentError("Cannot divide by zero");
    return Cash(value / divisor, currency);
  }

  bool operator >(Cash other) {
    if (currency == other.currency) {
      return value > other.value;
    }
    return value > other.convertTo(currency).value;
  }

  bool operator >=(Cash other) {
    if (currency == other.currency) {
      return value >= other.value;
    }
    return value >= other.convertTo(currency).value;
  }

  bool operator <(Cash other) {
    if (currency == other.currency) {
      return value < other.value;
    }
    return value < other.convertTo(currency).value;
  }

  bool operator <=(Cash other) {
    if (currency == other.currency) {
      return value <= other.value;
    }
    return value <= other.convertTo(currency).value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Cash) return false;
    if (currency == other.currency) return value == other.value;
    return value == other.convertTo(currency).value;
  }

  @override
  int get hashCode =>
      convertTo(Currency.usd).value.hashCode ^ Currency.usd.hashCode;
}
