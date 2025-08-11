import 'package:cash/cash.dart';

void main() {
  final usd = Currency.usd; // Get a currency objects directly
  final eur = Currency.fromSymbol("€"); // Get currency by symbol
  final jpy = Currency.fromCode("JPY"); // Get currency from code

  // Create Cash objects
  final walletUsd = Cash(100.0, usd);
  final walletEur = Cash(50.0, eur);

  print("Wallet in USD: $walletUsd"); // $100.00
  print("Wallet in EUR: $walletEur"); // €50.00

  // Convert EUR to USD
  final converted = walletEur.convertTo(usd);
  print("50 EUR in USD: $converted"); // $58.13

  // Add and subtract cash
  final total = walletUsd + walletEur;
  print("Total in USD: $total"); // $158.13

  // Multiple locals supported
  final en = jpy.resolveLocale("en");
  print("Display name (en): ${en.displayName}"); // Japanese Yen
  final de = jpy.resolveLocale("de");
  print("Display name (de): ${de.displayName}"); // Japanischer Yen
}
