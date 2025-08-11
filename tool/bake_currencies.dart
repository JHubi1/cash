import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:dart_style/dart_style.dart';

final currenciesFile = File("../lib/src/currencies/currencies.dart");
final localizationFile = File("../lib/src/currencies/localization.dart");
final localsDir = Directory("../lib/src/currencies/locals");
final docsFile = File("../currencies.md");
final readmeFile = File("../README.md");

final date = () {
  final now = DateTime.now();
  return "${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}";
}();

final Uri currenciesUri = Uri.parse(
  "https://api.github.com/repos/unicode-org/cldr-json/contents/cldr-json/cldr-numbers-full/main",
);
Uri currenciesData(String locale) => Uri.parse(
  "https://raw.githubusercontent.com/unicode-org/cldr-json/refs/heads/main/cldr-json/cldr-numbers-full/main/${locale.toLowerCase()}/currencies.json",
);
final Uri currenciesDataUri = Uri.parse(
  "https://raw.githubusercontent.com/unicode-org/cldr-json/refs/heads/main/cldr-json/cldr-core/supplemental/currencyData.json",
);

final Uri currencyValues = Uri.parse(
  "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json",
);
final Uri currencyValuesFallback = Uri.parse(
  "https://latest.currency-api.pages.dev/v1/currencies/usd.json",
);

void main(_) async {
  Directory.current = Platform.script.resolve(".").toFilePath();
  final s = Stopwatch()..start();

  final locals =
      (jsonDecode((await retry(() async => await http.get(currenciesUri))).body)
              as List)
          .map((e) => e['name'] as String)
          .toList()
        ..removeWhere((e) => e.contains("-"));
  final localeEn =
      (jsonDecode(
                (await retry(
                  () async => await http.get(currenciesData("en")),
                )).body,
              )
              as Map)["main"]["en"]["numbers"]["currencies"]
          as Map;

  final details =
      (jsonDecode(
                (await retry(
                  () async => await http.get(currenciesDataUri),
                )).body,
              )
              as Map)["supplemental"]["currencyData"]
          as Map;

  final values = Map<String, num>.from(
    (jsonDecode(
          (await () {
            Future<http.Response> values;
            try {
              values = retry(() async => await http.get(currencyValues));
            } catch (_) {
              values = retry(
                () async => await http.get(currencyValuesFallback),
              );
            }
            return values;
          }()).body,
        )
        as Map)["usd"],
  )..removeWhere((k, _) {
    for (var i in (details["region"] as Map).values) {
      final l = List<Map<String, dynamic>>.from(i);
      if (!l.any((e) => e.containsKey(k.toUpperCase()))) continue;

      final c = Map<String, String>.from(
        l.firstWhere((e) => e.containsKey(k.toUpperCase()))[k.toUpperCase()],
      );
      if (!c.containsKey("_to")) return false;
    }
    return true;
  });
  final currencies =
      values.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  // CURRENCIES

  String code(String currency) {
    if (currency == "try") return "kTry";
    return currency.toLowerCase();
  }

  String? symbolRaw(String currency) {
    final c = localeEn[currency.toUpperCase()];
    final s = c["symbol"] ?? c["symbol-alt-narrow"];
    if (s == currency.toUpperCase()) return null;
    return s;
  }

  String symbol(String currency) {
    final s = symbolRaw(currency);
    if (s != null) return "r\"$s\"";
    return "null";
  }

  final generatedCurrencies =
      "// GENERATION START\n"
      "${currencies.map((e) => "/// Currency object for the **${localeEn[e.key.toUpperCase()]["displayName"]}** (`${e.key.toUpperCase()}`${(symbolRaw(e.key) == null) ? "; no explicit symbol)" : ") with the symbol `${symbolRaw(e.key)!}`"}\nstatic final Currency ${code(e.key)} = Currency._(code: \"${e.key.toUpperCase()}\", symbol: ${symbol(e.key)}, exchangeRate: ${e.value}, exponent: ${details["fractions"][e.key.toUpperCase()]?["_digits"]});").join("\n")}"
      "\n\nstatic final Set<Currency> currencies = {${currencies.map((e) => code(e.key)).join(",")}};"
      "\n// GENERATION END";

  await currenciesFile.writeAsString(
    DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(
      (await currenciesFile.readAsString())
          .replaceAll(
            RegExp(
              r"\/\/ ?GENERATION START.*\/\/ ?GENERATION END",
              dotAll: true,
            ),
            generatedCurrencies,
          )
          .replaceFirst(
            RegExp(r"const _defaultExponent ?=.*;"),
            "const _defaultExponent = ${details["fractions"]["DEFAULT"]["_digits"]};",
          ),
    ),
  );

  // LOCALIZATION

  final usedLocals = <String>{};
  final usedLocalsClassNames = <String>{};
  for (var l in locals) {
    final localization =
        (l == "en")
            ? localeEn
            : (jsonDecode(
                      (await retry(
                        () async => await http.get(currenciesData(l)),
                      )).body,
                    )
                    as Map)["main"][l]["numbers"]["currencies"]
                as Map;
    localization
      ..removeWhere((_, v) => v["displayName"] == null)
      ..removeWhere(
        (k, _) =>
            !currencies.any((e) => e.key.toLowerCase() == k.toLowerCase()),
      );
    if (localization.isEmpty) continue;

    final className =
        "_container${l.substring(0, 1).toUpperCase()}${l.substring(1).toLowerCase()}";

    usedLocals.add(l);
    usedLocalsClassNames.add(className);

    final generatedLocalizationFile = File(
      "${localsDir.path}/${l.toLowerCase()}.dart",
    );
    final generatedLocalizationFileContent =
        "// This is an automatically generated file. Do not modify manually.\n// To regenerate this file, run the command 'dart run tool/bake_currencies.dart'\n\n"
        "part of '../localization.dart';\n\n"
        "final $className = CurrencyLocalizationContainer._(\nlocale: r\"$l\",\ncurrencies: {\n"
        "${localization.entries.map((e) {
          final displayName = e.value["displayName"] as String;
          final displayCountSingularRaw = e.value["displayCountSingular"] as String?;
          final displayCountSingular = displayCountSingularRaw != null ? "r\"$displayCountSingularRaw\"" : "null";
          final displayCountPluralRaw = e.value["displayCountPlural"] as String?;
          final displayCountPlural = displayCountPluralRaw != null ? "r\"$displayCountPluralRaw\"" : "null";
          return "\"${e.key}\": CurrencyLocalization._(displayName: r\"$displayName\", displayCountSingular: $displayCountSingular, displayCountPlural: $displayCountPlural),";
        }).join("\n")}"
        "\n});\n";

    await generatedLocalizationFile.create(recursive: true);
    await generatedLocalizationFile.writeAsString(
      DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(generatedLocalizationFileContent),
    );
  }

  await localizationFile.writeAsString(
    DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(
      (await localizationFile.readAsString())
          .replaceAll(
            RegExp(
              r"\/\/ ?GENERATION IMPORT START.*\/\/ ?GENERATION IMPORT END",
              dotAll: true,
            ),
            "// GENERATION IMPORT START\n"
            "${usedLocals.map((e) => "part 'locals/${e.toLowerCase()}.dart';").join("\n")}"
            "\n// GENERATION IMPORT END",
          )
          .replaceAll(
            RegExp(
              r"\/\/ ?GENERATION CONTENT START.*\/\/ ?GENERATION CONTENT END",
              dotAll: true,
            ),
            "// GENERATION CONTENT START\n"
            "final _localizations = {\n"
            "${usedLocalsClassNames.map((e) => "$e,").join("\n")}"
            "};"
            "\n// GENERATION CONTENT END",
          ),
    ),
  );

  int docsFileCurrenciesTableNameLength = 14;
  int docsFileCurrenciesTableSymbolLength = 6;
  for (var c in currencies) {
    final String displayName = localeEn[c.key.toUpperCase()]["displayName"];
    if (displayName.length > docsFileCurrenciesTableNameLength) {
      docsFileCurrenciesTableNameLength = displayName.length;
    }
    final symbol = symbolRaw(c.key) ?? "";
    if (symbol.length > docsFileCurrenciesTableSymbolLength) {
      docsFileCurrenciesTableSymbolLength = symbol.length;
    }
  }

  await (docsFile..createSync(recursive: true)).writeAsString(
    "# Currencies\n\n"
    "This file is automatically generated by the `bake_currencies.dart` script.\n\n"
    "Last updated at: **$date**\n\n"
    "- [Available Currencies](#available-currencies)\n- [Supported Locales](#supported-locales)\n\n"
    "## Available Currencies\n\n"
    "| Code | ${"Name (English)".padRight(docsFileCurrenciesTableNameLength)} | ${"Symbol".padRight(docsFileCurrenciesTableSymbolLength)} |\n"
    "| ---- | ${"-" * docsFileCurrenciesTableNameLength} | ${"-" * docsFileCurrenciesTableSymbolLength} |\n"
    "${currencies.map((e) {
      final String displayName = localeEn[e.key.toUpperCase()]["displayName"];
      final symbol = symbolRaw(e.key) ?? "";
      return "| ${e.key.toUpperCase().padRight(4)} | ${displayName.padRight(docsFileCurrenciesTableNameLength)} | ${symbol.padRight(docsFileCurrenciesTableSymbolLength)} |";
    }).join("\n")}\n\n"
    "## Supported Locales\n\n"
    "${usedLocals.map((e) => "`${e.toUpperCase()}`").join(", ")}\n",
  );

  await (readmeFile..createSync(recursive: true)).writeAsString(
    (await readmeFile.readAsString()).replaceFirst(
      RegExp(r"fetched on \*\*.*\*\*\."),
      "fetched on **$date**.",
    ),
  );

  print(
    "Generated ${currencies.length} currencies with ${usedLocals.length} locals in ${s.elapsedMilliseconds}ms",
  );
}
