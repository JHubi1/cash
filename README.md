# Cash

A universal money conversion and calculation library for Dart.

## Features

- Store money values in a consistent way
- Calculate with money values
- Convert between different currencies
- Support for multiple currencies (≈185) with exchange rates
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
