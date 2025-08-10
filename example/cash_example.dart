import 'package:cash/cash.dart';

void main() {
  final usd = Currency.usd; // Get a currency objects directly
  final eur = Currency.fromSymbol("€"); // Get currency by symbol
  final dem = Currency.fromCode("DEM"); // Get currency from code

  // Create Cash objects
  final walletUsd = Cash(100.0, usd);
  final walletEur = Cash(50.0, eur);

  print("Wallet in USD: $walletUsd"); // $100.00
  print("Wallet in EUR: $walletEur"); // €50.00

  // Convert EUR to USD
  final converted = walletEur.convertTo(usd);
  print("50 EUR in USD: $converted"); // $57.96

  // Add and subtract cash
  final total = walletUsd + walletEur;
  print("Total in USD: $total"); // $157.96

  // Multiple locals supported
  final en = dem.resolveLocale("en");
  print("Display name (en): ${en.displayName}"); // German Mark
  final de = dem.resolveLocale("de");
  print("Display name (de): ${de.displayName}"); // Deutsche Mark
}
