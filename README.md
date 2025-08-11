# Cash

A universal money conversion and calculation library for Dart.

## Features

- Store money values in a consistent way
- Calculate with money values
- Convert between different currencies
- Support for multiple currencies (≈160) with exchange rates
- Name and symbol for each currency in around 200 languages

> See [`currencies.md`](https://github.com/JHubi1/cash/blob/main/currencies.md) for a list of all available currencies and the supported locales.

## Installation

Install the package using:

```bash
dart pub add cash
```

## Usage

After installing the package, you can use it in your Dart or Flutter project:

```dart
import 'package:cash/cash.dart';

void main() {
  final money = Cash(100, Currency.usd);
  final moneyInEur = money.convertTo(Currency.eur);

  print('Converted Money: ${moneyInEur.toString()}');

  print('Double that: ${moneyInEur * 2}');
  print('Half that: ${moneyInEur / 2}');
}
```

For more examples, check out [the example file](https://github.com/JHubi1/cash/blob/main/example/cash_example.dart). For API documentation, see the [API docs](https://pub.dev/documentation/cash/latest/).

## Exchange Rates

This package has baked-in exchange rates for all currencies. These were last fetched on **2025-08-11**. The exchange rates are updated automatically when the package is updated.

If you need more up-to-date exchange rate data, you can use this static method of the `Currency` class:

```dart
Currency.refetchExchangeRates();
```

It will fetch the latest exchange rates from [fawazahmed0/exchange-api](https://github.com/fawazahmed0/exchange-api) and update the exchange rate of all currencies in the package. Note that this will not persist the data, so you will need to call this method every time you want to update the exchange rates.

You should override the `userAgent` argument of the `refetchExchangeRates` method to a unique value, such as your app name or package name, to avoid being rate-limited by the API.

You can also use `Currency.overwriteExchangeRate(double rate)` to overwrite the exchange rate of a specific currency manually:

```dart
Currency.eur.overwriteExchangeRate(1.2); // Means: 1 EUR = 1.2 USD
```
