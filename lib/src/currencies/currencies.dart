import 'dart:async';
import 'dart:convert';

import 'package:cash/src/currencies/localization.dart';
import 'package:cash/src/version.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

Uri _currencyValues({String date = "latest"}) {
  return Uri.parse(
    "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$date/v1/currencies/usd.json",
  );
}

Uri _currencyValuesFallback({String date = "latest"}) {
  return Uri.parse(
    "https://$date.currency-api.pages.dev/v1/currencies/usd.json",
  );
}

const _defaultExponent = 2;

/// A class representing a currency with its code, symbol, and exchange rate.
///
/// To get a currency object, use the static properties like [Currency.usd] or
/// get it by its code or symbol using [Currency.fromCode] or
/// [Currency.fromSymbol]. You can get a list of all available currencies in
/// [Currency.currencies].
///
/// ***Careful***: If you access [Currency.currencies] or use one of the getter
/// methods, Dart's tree shaker will not be able to remove unused currencies.
/// Avoid using these methods if not necessarily needed.
///
/// A static exchange rate for a currency to USD is baked into the library; it
/// enables the convertion between currencies. This is fine in most cases, but
/// if you need more recent and accurate exchange rates, you can use
/// [Currency.refetchExchangeRates] to update the exchange rates or all
/// currencies. If this is not accurate enough, you can also overwrite the
/// exchange rate of a currency with your own value using
/// [Currency.overwriteExchangeRate].
///
/// You can get the localization for a currency in a specific locale using
/// [Currency.resolveLocale].
class Currency {
  /// Identification code of the currency.
  ///
  /// This is usually a three-letter code (ISO 4217) like "USD" for US Dollar.
  /// For custom currencies, this can be any string.
  final String code;

  /// Symbol of the currency, if available.
  ///
  /// This is usually a single character string like "$" for US Dollar.
  /// If the currency does not have a symbol, this can be `null`.
  ///
  /// If no [symbol] is available, [code] may be used as a fallback.
  final String? symbol;

  /// Whether this currency is a custom currency.
  final bool isCustom;

  /// Exchange rate of the currency to USD.
  ///
  /// This value may also be used to convert between currencies other than USD.
  ///
  /// By default, this value is baked into the library. It can be updated by
  /// calling [Currency.refetchExchangeRates] or overwritten with
  /// [Currency.overwriteExchangeRate].
  double get exchangeRate => _exchangeRate;
  double _exchangeRate;

  /// Exponent of the currency.
  ///
  /// This is the number of digits after the decimal point that are used to
  /// represent the smallest unit of the currency.
  ///
  /// For example, for USD, this is 2, because the smallest unit is a cent.
  /// For JPY (Japanese Yen), this is 0, because it does not have a subunit.
  final int exponent;

  Currency._({
    required this.code,
    required this.symbol,
    required double exchangeRate,
    required int? exponent,
  }) : isCustom = false,
       _exchangeRate = exchangeRate,
       exponent = exponent ?? _defaultExponent;

  /// Creates a custom currency.
  ///
  /// This constructor is used to create a currency that is not part of the
  /// baked-in currencies. It allows you to define a currency with a custom
  /// code, symbol and exchange rate.
  Currency.custom({
    required this.code,
    this.symbol,
    double? exchangeRate,
    this.exponent = _defaultExponent,
  }) : isCustom = true,
       _exchangeRate = exchangeRate ?? 1;

  /// Get a currency object by its code.
  ///
  /// If the code is not found, an [ArgumentError] is thrown.
  factory Currency.fromCode(String code) {
    try {
      return currencies.firstWhere((c) => c.code == code.toUpperCase());
    } catch (_) {
      throw ArgumentError.value(code, "code", "Unknown currency code");
    }
  }

  /// Get a currency object by its symbol.
  ///
  /// If the symbol is not found, an [ArgumentError] is thrown.
  factory Currency.fromSymbol(String symbol) {
    try {
      return currencies.firstWhere((c) => c.symbol == symbol);
    } catch (_) {
      throw ArgumentError.value(symbol, "symbol", "Unknown currency symbol");
    }
  }

  @override
  String toString() => "$code ($symbol)";

  /// Get a [CurrencyLocalization] for a specific locale.
  ///
  /// This method resolves the localization for this currency in the given
  /// locale. This may be useful for displaying the currency in a user-friendly
  /// way, such as in a UI or for formatting.
  ///
  /// If the locale is not found, an [ArgumentError] is thrown.
  ///
  /// If the locale is found, but the currency is not available in that locale,
  /// an [UnsupportedError] is thrown.
  CurrencyLocalization resolveLocale(String locale) {
    final container = CurrencyLocalizationContainer.resolveLocale(locale);
    if (container == null) {
      throw ArgumentError.value(
        locale,
        "locale",
        "No localization found for locale",
      );
    }
    final localization = container[code];
    if (localization == null) {
      throw UnsupportedError(
        "No localization found for currency '$code' in locale '$locale'",
      );
    }
    return localization;
  }

  /// Overwrite the exchange rate of this currency.
  ///
  /// Only use this if you know what you are doing. The usage of the
  /// [Currency.refetchExchangeRates] method is preferred.
  void overwriteExchangeRate(double rate) => _exchangeRate = rate;

  /// Refetch the exchange rates for all currencies.
  ///
  /// You may want to use this if you need more recent exchange rates than
  /// the baked-in ones.
  ///
  /// You should pass a custom [userAgent] to identify your application,
  /// otherwise the used API may block your requests.
  static void refetchExchangeRates({
    http.Client? httpClient,
    String userAgent = "cash/$version (https://pub.dev/packages/cash)",
    RetryOptions retryOptions = const RetryOptions(),
    Duration timeout = const Duration(seconds: 10),
    DateTime? date,
  }) async {
    httpClient ??= http.Client();

    String dateYear;
    if (date == null) {
      dateYear = "latest";
    } else {
      dateYear =
          "${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}";
    }

    http.Response res;
    try {
      res = await retryOptions.retry(() async {
        final res = await httpClient!
            .get(
              _currencyValues(date: dateYear),
              headers: {"User-Agent": userAgent},
            )
            .timeout(timeout);
        if (res.statusCode != 200) {
          throw Exception(
            "Failed to fetch exchange rate: ${res.statusCode} – ${res.reasonPhrase}",
          );
        }
        return res;
      }, retryIf: (e) => e is TimeoutException || e is http.ClientException);
    } catch (_) {
      res = await retryOptions.retry(() async {
        final res = await httpClient!
            .get(
              _currencyValuesFallback(date: dateYear),
              headers: {"User-Agent": userAgent},
            )
            .timeout(timeout);
        if (res.statusCode != 200) {
          throw Exception(
            "Failed to fetch exchange rate: ${res.statusCode} ${res.reasonPhrase}",
          );
        }
        return res;
      });
    }

    final values = Map<String, num>.from((jsonDecode(res.body) as Map)["usd"]);
    for (var i in currencies) {
      if (values.containsKey(i.code.toLowerCase())) {
        i._exchangeRate = values[i.code.toLowerCase()]!.toDouble();
      }
    }
  }

  // GENERATION START
  /// Currency object for the **United Arab Emirates Dirham** (`AED`; no explicit symbol)
  static final Currency aed = Currency._(
    code: "AED",
    symbol: null,
    exchangeRate: 3.6725,
    exponent: null,
  );

  /// Currency object for the **Afghan Afghani** (`AFN`; no explicit symbol)
  static final Currency afn = Currency._(
    code: "AFN",
    symbol: null,
    exchangeRate: 68.25367429,
    exponent: 0,
  );

  /// Currency object for the **Albanian Lek** (`ALL`; no explicit symbol)
  static final Currency all = Currency._(
    code: "ALL",
    symbol: null,
    exchangeRate: 83.49904635,
    exponent: 0,
  );

  /// Currency object for the **Armenian Dram** (`AMD`; no explicit symbol)
  static final Currency amd = Currency._(
    code: "AMD",
    symbol: null,
    exchangeRate: 388.27748875,
    exponent: 2,
  );

  /// Currency object for the **Angolan Kwanza** (`AOA`; no explicit symbol)
  static final Currency aoa = Currency._(
    code: "AOA",
    symbol: null,
    exchangeRate: 911.95513247,
    exponent: null,
  );

  /// Currency object for the **Argentine Peso** (`ARS`; no explicit symbol)
  static final Currency ars = Currency._(
    code: "ARS",
    symbol: null,
    exchangeRate: 1325.30625191,
    exponent: null,
  );

  /// Currency object for the **Australian Dollar** (`AUD`) with the symbol `A$`
  static final Currency aud = Currency._(
    code: "AUD",
    symbol: r"A$",
    exchangeRate: 1.5329594,
    exponent: null,
  );

  /// Currency object for the **Aruban Florin** (`AWG`; no explicit symbol)
  static final Currency awg = Currency._(
    code: "AWG",
    symbol: null,
    exchangeRate: 1.79,
    exponent: null,
  );

  /// Currency object for the **Azerbaijani Manat** (`AZN`; no explicit symbol)
  static final Currency azn = Currency._(
    code: "AZN",
    symbol: null,
    exchangeRate: 1.7,
    exponent: null,
  );

  /// Currency object for the **Bosnia-Herzegovina Convertible Mark** (`BAM`; no explicit symbol)
  static final Currency bam = Currency._(
    code: "BAM",
    symbol: null,
    exchangeRate: 1.68218367,
    exponent: null,
  );

  /// Currency object for the **Barbadian Dollar** (`BBD`; no explicit symbol)
  static final Currency bbd = Currency._(
    code: "BBD",
    symbol: null,
    exchangeRate: 2,
    exponent: null,
  );

  /// Currency object for the **Bangladeshi Taka** (`BDT`; no explicit symbol)
  static final Currency bdt = Currency._(
    code: "BDT",
    symbol: null,
    exchangeRate: 121.45196445,
    exponent: null,
  );

  /// Currency object for the **Bulgarian Lev** (`BGN`; no explicit symbol)
  static final Currency bgn = Currency._(
    code: "BGN",
    symbol: null,
    exchangeRate: 1.68218367,
    exponent: null,
  );

  /// Currency object for the **Bahraini Dinar** (`BHD`; no explicit symbol)
  static final Currency bhd = Currency._(
    code: "BHD",
    symbol: null,
    exchangeRate: 0.376,
    exponent: 3,
  );

  /// Currency object for the **Burundian Franc** (`BIF`; no explicit symbol)
  static final Currency bif = Currency._(
    code: "BIF",
    symbol: null,
    exchangeRate: 2974.48695417,
    exponent: 0,
  );

  /// Currency object for the **Bermudan Dollar** (`BMD`; no explicit symbol)
  static final Currency bmd = Currency._(
    code: "BMD",
    symbol: null,
    exchangeRate: 1,
    exponent: null,
  );

  /// Currency object for the **Brunei Dollar** (`BND`; no explicit symbol)
  static final Currency bnd = Currency._(
    code: "BND",
    symbol: null,
    exchangeRate: 1.28481521,
    exponent: null,
  );

  /// Currency object for the **Bolivian Boliviano** (`BOB`; no explicit symbol)
  static final Currency bob = Currency._(
    code: "BOB",
    symbol: null,
    exchangeRate: 6.89891787,
    exponent: null,
  );

  /// Currency object for the **Brazilian Real** (`BRL`) with the symbol `R$`
  static final Currency brl = Currency._(
    code: "BRL",
    symbol: r"R$",
    exchangeRate: 5.43343771,
    exponent: null,
  );

  /// Currency object for the **Bahamian Dollar** (`BSD`; no explicit symbol)
  static final Currency bsd = Currency._(
    code: "BSD",
    symbol: null,
    exchangeRate: 1,
    exponent: null,
  );

  /// Currency object for the **Bhutanese Ngultrum** (`BTN`; no explicit symbol)
  static final Currency btn = Currency._(
    code: "BTN",
    symbol: null,
    exchangeRate: 87.66481963,
    exponent: null,
  );

  /// Currency object for the **Botswanan Pula** (`BWP`; no explicit symbol)
  static final Currency bwp = Currency._(
    code: "BWP",
    symbol: null,
    exchangeRate: 14.29415117,
    exponent: null,
  );

  /// Currency object for the **Belarusian Ruble** (`BYN`; no explicit symbol)
  static final Currency byn = Currency._(
    code: "BYN",
    symbol: null,
    exchangeRate: 3.29619858,
    exponent: 2,
  );

  /// Currency object for the **Belize Dollar** (`BZD`; no explicit symbol)
  static final Currency bzd = Currency._(
    code: "BZD",
    symbol: null,
    exchangeRate: 2.00602036,
    exponent: null,
  );

  /// Currency object for the **Canadian Dollar** (`CAD`) with the symbol `CA$`
  static final Currency cad = Currency._(
    code: "CAD",
    symbol: r"CA$",
    exchangeRate: 1.37580863,
    exponent: 2,
  );

  /// Currency object for the **Congolese Franc** (`CDF`; no explicit symbol)
  static final Currency cdf = Currency._(
    code: "CDF",
    symbol: null,
    exchangeRate: 2877.94711591,
    exponent: null,
  );

  /// Currency object for the **Swiss Franc** (`CHF`; no explicit symbol)
  static final Currency chf = Currency._(
    code: "CHF",
    symbol: null,
    exchangeRate: 0.80923216,
    exponent: 2,
  );

  /// Currency object for the **Chilean Peso** (`CLP`; no explicit symbol)
  static final Currency clp = Currency._(
    code: "CLP",
    symbol: null,
    exchangeRate: 966.0614869,
    exponent: 0,
  );

  /// Currency object for the **Chinese Yuan (offshore)** (`CNH`; no explicit symbol)
  static final Currency cnh = Currency._(
    code: "CNH",
    symbol: null,
    exchangeRate: 7.18227497,
    exponent: null,
  );

  /// Currency object for the **Chinese Yuan** (`CNY`) with the symbol `CN¥`
  static final Currency cny = Currency._(
    code: "CNY",
    symbol: r"CN¥",
    exchangeRate: 7.1837319,
    exponent: null,
  );

  /// Currency object for the **Colombian Peso** (`COP`; no explicit symbol)
  static final Currency cop = Currency._(
    code: "COP",
    symbol: null,
    exchangeRate: 4050.9827017,
    exponent: 2,
  );

  /// Currency object for the **Costa Rican Colón** (`CRC`; no explicit symbol)
  static final Currency crc = Currency._(
    code: "CRC",
    symbol: null,
    exchangeRate: 505.60958209,
    exponent: 2,
  );

  /// Currency object for the **Cuban Peso** (`CUP`; no explicit symbol)
  static final Currency cup = Currency._(
    code: "CUP",
    symbol: null,
    exchangeRate: 23.92518601,
    exponent: null,
  );

  /// Currency object for the **Cape Verdean Escudo** (`CVE`; no explicit symbol)
  static final Currency cve = Currency._(
    code: "CVE",
    symbol: null,
    exchangeRate: 94.84177726,
    exponent: null,
  );

  /// Currency object for the **Czech Koruna** (`CZK`; no explicit symbol)
  static final Currency czk = Currency._(
    code: "CZK",
    symbol: null,
    exchangeRate: 20.99394321,
    exponent: 2,
  );

  /// Currency object for the **Djiboutian Franc** (`DJF`; no explicit symbol)
  static final Currency djf = Currency._(
    code: "DJF",
    symbol: null,
    exchangeRate: 178.50625652,
    exponent: 0,
  );

  /// Currency object for the **Danish Krone** (`DKK`; no explicit symbol)
  static final Currency dkk = Currency._(
    code: "DKK",
    symbol: null,
    exchangeRate: 6.4105467,
    exponent: 2,
  );

  /// Currency object for the **Dominican Peso** (`DOP`; no explicit symbol)
  static final Currency dop = Currency._(
    code: "DOP",
    symbol: null,
    exchangeRate: 61.07433689,
    exponent: null,
  );

  /// Currency object for the **Algerian Dinar** (`DZD`; no explicit symbol)
  static final Currency dzd = Currency._(
    code: "DZD",
    symbol: null,
    exchangeRate: 129.92094835,
    exponent: null,
  );

  /// Currency object for the **Egyptian Pound** (`EGP`; no explicit symbol)
  static final Currency egp = Currency._(
    code: "EGP",
    symbol: null,
    exchangeRate: 48.55349268,
    exponent: null,
  );

  /// Currency object for the **Eritrean Nakfa** (`ERN`; no explicit symbol)
  static final Currency ern = Currency._(
    code: "ERN",
    symbol: null,
    exchangeRate: 15,
    exponent: null,
  );

  /// Currency object for the **Ethiopian Birr** (`ETB`; no explicit symbol)
  static final Currency etb = Currency._(
    code: "ETB",
    symbol: null,
    exchangeRate: 138.56445821,
    exponent: null,
  );

  /// Currency object for the **Euro** (`EUR`) with the symbol `€`
  static final Currency eur = Currency._(
    code: "EUR",
    symbol: r"€",
    exchangeRate: 0.86008685,
    exponent: null,
  );

  /// Currency object for the **Fijian Dollar** (`FJD`; no explicit symbol)
  static final Currency fjd = Currency._(
    code: "FJD",
    symbol: null,
    exchangeRate: 2.25275286,
    exponent: null,
  );

  /// Currency object for the **Falkland Islands Pound** (`FKP`; no explicit symbol)
  static final Currency fkp = Currency._(
    code: "FKP",
    symbol: null,
    exchangeRate: 0.74388527,
    exponent: null,
  );

  /// Currency object for the **British Pound** (`GBP`) with the symbol `£`
  static final Currency gbp = Currency._(
    code: "GBP",
    symbol: r"£",
    exchangeRate: 0.74388527,
    exponent: null,
  );

  /// Currency object for the **Georgian Lari** (`GEL`; no explicit symbol)
  static final Currency gel = Currency._(
    code: "GEL",
    symbol: null,
    exchangeRate: 2.69640001,
    exponent: null,
  );

  /// Currency object for the **Ghanaian Cedi** (`GHS`; no explicit symbol)
  static final Currency ghs = Currency._(
    code: "GHS",
    symbol: null,
    exchangeRate: 10.54962566,
    exponent: null,
  );

  /// Currency object for the **Gibraltar Pound** (`GIP`; no explicit symbol)
  static final Currency gip = Currency._(
    code: "GIP",
    symbol: null,
    exchangeRate: 0.74388527,
    exponent: null,
  );

  /// Currency object for the **Gambian Dalasi** (`GMD`; no explicit symbol)
  static final Currency gmd = Currency._(
    code: "GMD",
    symbol: null,
    exchangeRate: 72.5089882,
    exponent: null,
  );

  /// Currency object for the **Guinean Franc** (`GNF`; no explicit symbol)
  static final Currency gnf = Currency._(
    code: "GNF",
    symbol: null,
    exchangeRate: 8672.62360821,
    exponent: 0,
  );

  /// Currency object for the **Guatemalan Quetzal** (`GTQ`; no explicit symbol)
  static final Currency gtq = Currency._(
    code: "GTQ",
    symbol: null,
    exchangeRate: 7.66433444,
    exponent: null,
  );

  /// Currency object for the **Guyanaese Dollar** (`GYD`; no explicit symbol)
  static final Currency gyd = Currency._(
    code: "GYD",
    symbol: null,
    exchangeRate: 209.03369868,
    exponent: 2,
  );

  /// Currency object for the **Hong Kong Dollar** (`HKD`) with the symbol `HK$`
  static final Currency hkd = Currency._(
    code: "HKD",
    symbol: r"HK$",
    exchangeRate: 7.85036534,
    exponent: null,
  );

  /// Currency object for the **Honduran Lempira** (`HNL`; no explicit symbol)
  static final Currency hnl = Currency._(
    code: "HNL",
    symbol: null,
    exchangeRate: 26.20267799,
    exponent: null,
  );

  /// Currency object for the **Haitian Gourde** (`HTG`; no explicit symbol)
  static final Currency htg = Currency._(
    code: "HTG",
    symbol: null,
    exchangeRate: 130.80253497,
    exponent: null,
  );

  /// Currency object for the **Hungarian Forint** (`HUF`; no explicit symbol)
  static final Currency huf = Currency._(
    code: "HUF",
    symbol: null,
    exchangeRate: 339.56584141,
    exponent: 2,
  );

  /// Currency object for the **Indonesian Rupiah** (`IDR`; no explicit symbol)
  static final Currency idr = Currency._(
    code: "IDR",
    symbol: null,
    exchangeRate: 16293.08313904,
    exponent: 2,
  );

  /// Currency object for the **Israeli New Shekel** (`ILS`) with the symbol `₪`
  static final Currency ils = Currency._(
    code: "ILS",
    symbol: r"₪",
    exchangeRate: 3.43319627,
    exponent: null,
  );

  /// Currency object for the **Indian Rupee** (`INR`) with the symbol `₹`
  static final Currency inr = Currency._(
    code: "INR",
    symbol: r"₹",
    exchangeRate: 87.66481963,
    exponent: null,
  );

  /// Currency object for the **Iraqi Dinar** (`IQD`; no explicit symbol)
  static final Currency iqd = Currency._(
    code: "IQD",
    symbol: null,
    exchangeRate: 1309.52365152,
    exponent: 0,
  );

  /// Currency object for the **Iranian Rial** (`IRR`; no explicit symbol)
  static final Currency irr = Currency._(
    code: "IRR",
    symbol: null,
    exchangeRate: 42010.48854772,
    exponent: 0,
  );

  /// Currency object for the **Icelandic Króna** (`ISK`; no explicit symbol)
  static final Currency isk = Currency._(
    code: "ISK",
    symbol: null,
    exchangeRate: 122.80834219,
    exponent: 0,
  );

  /// Currency object for the **Jamaican Dollar** (`JMD`; no explicit symbol)
  static final Currency jmd = Currency._(
    code: "JMD",
    symbol: null,
    exchangeRate: 160.04660347,
    exponent: null,
  );

  /// Currency object for the **Jordanian Dinar** (`JOD`; no explicit symbol)
  static final Currency jod = Currency._(
    code: "JOD",
    symbol: null,
    exchangeRate: 0.709,
    exponent: 3,
  );

  /// Currency object for the **Japanese Yen** (`JPY`) with the symbol `¥`
  static final Currency jpy = Currency._(
    code: "JPY",
    symbol: r"¥",
    exchangeRate: 147.68279052,
    exponent: 0,
  );

  /// Currency object for the **Kenyan Shilling** (`KES`; no explicit symbol)
  static final Currency kes = Currency._(
    code: "KES",
    symbol: null,
    exchangeRate: 129.18498124,
    exponent: null,
  );

  /// Currency object for the **Kyrgystani Som** (`KGS`; no explicit symbol)
  static final Currency kgs = Currency._(
    code: "KGS",
    symbol: null,
    exchangeRate: 87.45001862,
    exponent: null,
  );

  /// Currency object for the **Cambodian Riel** (`KHR`; no explicit symbol)
  static final Currency khr = Currency._(
    code: "KHR",
    symbol: null,
    exchangeRate: 4003.92695653,
    exponent: null,
  );

  /// Currency object for the **Comorian Franc** (`KMF`; no explicit symbol)
  static final Currency kmf = Currency._(
    code: "KMF",
    symbol: null,
    exchangeRate: 423.13499376,
    exponent: 0,
  );

  /// Currency object for the **North Korean Won** (`KPW`; no explicit symbol)
  static final Currency kpw = Currency._(
    code: "KPW",
    symbol: null,
    exchangeRate: 900,
    exponent: 0,
  );

  /// Currency object for the **South Korean Won** (`KRW`) with the symbol `₩`
  static final Currency krw = Currency._(
    code: "KRW",
    symbol: r"₩",
    exchangeRate: 1389.42725696,
    exponent: 0,
  );

  /// Currency object for the **Kuwaiti Dinar** (`KWD`; no explicit symbol)
  static final Currency kwd = Currency._(
    code: "KWD",
    symbol: null,
    exchangeRate: 0.30552434,
    exponent: 3,
  );

  /// Currency object for the **Cayman Islands Dollar** (`KYD`; no explicit symbol)
  static final Currency kyd = Currency._(
    code: "KYD",
    symbol: null,
    exchangeRate: 0.82000373,
    exponent: null,
  );

  /// Currency object for the **Kazakhstani Tenge** (`KZT`; no explicit symbol)
  static final Currency kzt = Currency._(
    code: "KZT",
    symbol: null,
    exchangeRate: 541.69285785,
    exponent: null,
  );

  /// Currency object for the **Laotian Kip** (`LAK`; no explicit symbol)
  static final Currency lak = Currency._(
    code: "LAK",
    symbol: null,
    exchangeRate: 21600.91304807,
    exponent: 0,
  );

  /// Currency object for the **Lebanese Pound** (`LBP`; no explicit symbol)
  static final Currency lbp = Currency._(
    code: "LBP",
    symbol: null,
    exchangeRate: 89516.11946118,
    exponent: 0,
  );

  /// Currency object for the **Sri Lankan Rupee** (`LKR`; no explicit symbol)
  static final Currency lkr = Currency._(
    code: "LKR",
    symbol: null,
    exchangeRate: 300.71463439,
    exponent: null,
  );

  /// Currency object for the **Liberian Dollar** (`LRD`; no explicit symbol)
  static final Currency lrd = Currency._(
    code: "LRD",
    symbol: null,
    exchangeRate: 200.55463128,
    exponent: null,
  );

  /// Currency object for the **Lesotho Loti** (`LSL`; no explicit symbol)
  static final Currency lsl = Currency._(
    code: "LSL",
    symbol: null,
    exchangeRate: 17.74246465,
    exponent: null,
  );

  /// Currency object for the **Libyan Dinar** (`LYD`; no explicit symbol)
  static final Currency lyd = Currency._(
    code: "LYD",
    symbol: null,
    exchangeRate: 5.42697192,
    exponent: 3,
  );

  /// Currency object for the **Moroccan Dirham** (`MAD`; no explicit symbol)
  static final Currency mad = Currency._(
    code: "MAD",
    symbol: null,
    exchangeRate: 9.03120298,
    exponent: null,
  );

  /// Currency object for the **Moldovan Leu** (`MDL`; no explicit symbol)
  static final Currency mdl = Currency._(
    code: "MDL",
    symbol: null,
    exchangeRate: 16.88198402,
    exponent: null,
  );

  /// Currency object for the **Malagasy Ariary** (`MGA`; no explicit symbol)
  static final Currency mga = Currency._(
    code: "MGA",
    symbol: null,
    exchangeRate: 4416.74346501,
    exponent: 0,
  );

  /// Currency object for the **Macedonian Denar** (`MKD`; no explicit symbol)
  static final Currency mkd = Currency._(
    code: "MKD",
    symbol: null,
    exchangeRate: 52.82149456,
    exponent: null,
  );

  /// Currency object for the **Myanmar Kyat** (`MMK`; no explicit symbol)
  static final Currency mmk = Currency._(
    code: "MMK",
    symbol: null,
    exchangeRate: 2099.83364474,
    exponent: 0,
  );

  /// Currency object for the **Mongolian Tugrik** (`MNT`; no explicit symbol)
  static final Currency mnt = Currency._(
    code: "MNT",
    symbol: null,
    exchangeRate: 3591.41880915,
    exponent: 2,
  );

  /// Currency object for the **Macanese Pataca** (`MOP`; no explicit symbol)
  static final Currency mop = Currency._(
    code: "MOP",
    symbol: null,
    exchangeRate: 8.0858763,
    exponent: null,
  );

  /// Currency object for the **Mauritanian Ouguiya** (`MRU`; no explicit symbol)
  static final Currency mru = Currency._(
    code: "MRU",
    symbol: null,
    exchangeRate: 39.86445851,
    exponent: null,
  );

  /// Currency object for the **Mauritian Rupee** (`MUR`; no explicit symbol)
  static final Currency mur = Currency._(
    code: "MUR",
    symbol: null,
    exchangeRate: 45.42333108,
    exponent: 2,
  );

  /// Currency object for the **Maldivian Rufiyaa** (`MVR`; no explicit symbol)
  static final Currency mvr = Currency._(
    code: "MVR",
    symbol: null,
    exchangeRate: 15.4270727,
    exponent: null,
  );

  /// Currency object for the **Malawian Kwacha** (`MWK`; no explicit symbol)
  static final Currency mwk = Currency._(
    code: "MWK",
    symbol: null,
    exchangeRate: 1733.20710815,
    exponent: null,
  );

  /// Currency object for the **Mexican Peso** (`MXN`) with the symbol `MX$`
  static final Currency mxn = Currency._(
    code: "MXN",
    symbol: r"MX$",
    exchangeRate: 18.54447249,
    exponent: null,
  );

  /// Currency object for the **Mexican Investment Unit** (`MXV`; no explicit symbol)
  static final Currency mxv = Currency._(
    code: "MXV",
    symbol: null,
    exchangeRate: 2.17680999,
    exponent: null,
  );

  /// Currency object for the **Malaysian Ringgit** (`MYR`; no explicit symbol)
  static final Currency myr = Currency._(
    code: "MYR",
    symbol: null,
    exchangeRate: 4.23950283,
    exponent: null,
  );

  /// Currency object for the **Mozambican Metical** (`MZN`; no explicit symbol)
  static final Currency mzn = Currency._(
    code: "MZN",
    symbol: null,
    exchangeRate: 63.89089601,
    exponent: null,
  );

  /// Currency object for the **Namibian Dollar** (`NAD`; no explicit symbol)
  static final Currency nad = Currency._(
    code: "NAD",
    symbol: null,
    exchangeRate: 17.74246465,
    exponent: null,
  );

  /// Currency object for the **Nigerian Naira** (`NGN`; no explicit symbol)
  static final Currency ngn = Currency._(
    code: "NGN",
    symbol: null,
    exchangeRate: 1533.46204367,
    exponent: null,
  );

  /// Currency object for the **Nicaraguan Córdoba** (`NIO`; no explicit symbol)
  static final Currency nio = Currency._(
    code: "NIO",
    symbol: null,
    exchangeRate: 36.65428193,
    exponent: null,
  );

  /// Currency object for the **Norwegian Krone** (`NOK`; no explicit symbol)
  static final Currency nok = Currency._(
    code: "NOK",
    symbol: null,
    exchangeRate: 10.27580643,
    exponent: 2,
  );

  /// Currency object for the **Nepalese Rupee** (`NPR`; no explicit symbol)
  static final Currency npr = Currency._(
    code: "NPR",
    symbol: null,
    exchangeRate: 140.32946003,
    exponent: null,
  );

  /// Currency object for the **New Zealand Dollar** (`NZD`) with the symbol `NZ$`
  static final Currency nzd = Currency._(
    code: "NZD",
    symbol: r"NZ$",
    exchangeRate: 1.67832401,
    exponent: null,
  );

  /// Currency object for the **Omani Rial** (`OMR`; no explicit symbol)
  static final Currency omr = Currency._(
    code: "OMR",
    symbol: null,
    exchangeRate: 0.38505283,
    exponent: 3,
  );

  /// Currency object for the **Panamanian Balboa** (`PAB`; no explicit symbol)
  static final Currency pab = Currency._(
    code: "PAB",
    symbol: null,
    exchangeRate: 1,
    exponent: null,
  );

  /// Currency object for the **Peruvian Sol** (`PEN`; no explicit symbol)
  static final Currency pen = Currency._(
    code: "PEN",
    symbol: null,
    exchangeRate: 3.527745,
    exponent: null,
  );

  /// Currency object for the **Papua New Guinean Kina** (`PGK`; no explicit symbol)
  static final Currency pgk = Currency._(
    code: "PGK",
    symbol: null,
    exchangeRate: 4.14374033,
    exponent: null,
  );

  /// Currency object for the **Philippine Peso** (`PHP`) with the symbol `₱`
  static final Currency php = Currency._(
    code: "PHP",
    symbol: r"₱",
    exchangeRate: 56.85383176,
    exponent: null,
  );

  /// Currency object for the **Pakistani Rupee** (`PKR`; no explicit symbol)
  static final Currency pkr = Currency._(
    code: "PKR",
    symbol: null,
    exchangeRate: 283.23290295,
    exponent: 2,
  );

  /// Currency object for the **Polish Zloty** (`PLN`; no explicit symbol)
  static final Currency pln = Currency._(
    code: "PLN",
    symbol: null,
    exchangeRate: 3.64340821,
    exponent: null,
  );

  /// Currency object for the **Paraguayan Guarani** (`PYG`; no explicit symbol)
  static final Currency pyg = Currency._(
    code: "PYG",
    symbol: null,
    exchangeRate: 7474.38445868,
    exponent: 0,
  );

  /// Currency object for the **Qatari Riyal** (`QAR`; no explicit symbol)
  static final Currency qar = Currency._(
    code: "QAR",
    symbol: null,
    exchangeRate: 3.64,
    exponent: null,
  );

  /// Currency object for the **Romanian Leu** (`RON`; no explicit symbol)
  static final Currency ron = Currency._(
    code: "RON",
    symbol: null,
    exchangeRate: 4.35578023,
    exponent: null,
  );

  /// Currency object for the **Serbian Dinar** (`RSD`; no explicit symbol)
  static final Currency rsd = Currency._(
    code: "RSD",
    symbol: null,
    exchangeRate: 100.60730473,
    exponent: 0,
  );

  /// Currency object for the **Russian Ruble** (`RUB`; no explicit symbol)
  static final Currency rub = Currency._(
    code: "RUB",
    symbol: null,
    exchangeRate: 79.95263927,
    exponent: null,
  );

  /// Currency object for the **Rwandan Franc** (`RWF`; no explicit symbol)
  static final Currency rwf = Currency._(
    code: "RWF",
    symbol: null,
    exchangeRate: 1445.72424146,
    exponent: 0,
  );

  /// Currency object for the **Saudi Riyal** (`SAR`; no explicit symbol)
  static final Currency sar = Currency._(
    code: "SAR",
    symbol: null,
    exchangeRate: 3.75,
    exponent: null,
  );

  /// Currency object for the **Solomon Islands Dollar** (`SBD`; no explicit symbol)
  static final Currency sbd = Currency._(
    code: "SBD",
    symbol: null,
    exchangeRate: 8.49978243,
    exponent: null,
  );

  /// Currency object for the **Seychellois Rupee** (`SCR`; no explicit symbol)
  static final Currency scr = Currency._(
    code: "SCR",
    symbol: null,
    exchangeRate: 14.34841902,
    exponent: null,
  );

  /// Currency object for the **Sudanese Pound** (`SDG`; no explicit symbol)
  static final Currency sdg = Currency._(
    code: "SDG",
    symbol: null,
    exchangeRate: 600.14681146,
    exponent: null,
  );

  /// Currency object for the **Swedish Krona** (`SEK`; no explicit symbol)
  static final Currency sek = Currency._(
    code: "SEK",
    symbol: null,
    exchangeRate: 9.57607945,
    exponent: 2,
  );

  /// Currency object for the **Singapore Dollar** (`SGD`; no explicit symbol)
  static final Currency sgd = Currency._(
    code: "SGD",
    symbol: null,
    exchangeRate: 1.28481521,
    exponent: null,
  );

  /// Currency object for the **St. Helena Pound** (`SHP`; no explicit symbol)
  static final Currency shp = Currency._(
    code: "SHP",
    symbol: null,
    exchangeRate: 0.74388527,
    exponent: null,
  );

  /// Currency object for the **Sierra Leonean Leone** (`SLE`; no explicit symbol)
  static final Currency sle = Currency._(
    code: "SLE",
    symbol: null,
    exchangeRate: 22.70504129,
    exponent: 2,
  );

  /// Currency object for the **Somali Shilling** (`SOS`; no explicit symbol)
  static final Currency sos = Currency._(
    code: "SOS",
    symbol: null,
    exchangeRate: 571.14378276,
    exponent: 0,
  );

  /// Currency object for the **Surinamese Dollar** (`SRD`; no explicit symbol)
  static final Currency srd = Currency._(
    code: "SRD",
    symbol: null,
    exchangeRate: 37.18410305,
    exponent: null,
  );

  /// Currency object for the **São Tomé & Príncipe Dobra** (`STN`; no explicit symbol)
  static final Currency stn = Currency._(
    code: "STN",
    symbol: null,
    exchangeRate: 21.18756202,
    exponent: null,
  );

  /// Currency object for the **Syrian Pound** (`SYP`; no explicit symbol)
  static final Currency syp = Currency._(
    code: "SYP",
    symbol: null,
    exchangeRate: 13001.85090007,
    exponent: 0,
  );

  /// Currency object for the **Swazi Lilangeni** (`SZL`; no explicit symbol)
  static final Currency szl = Currency._(
    code: "SZL",
    symbol: null,
    exchangeRate: 17.74246465,
    exponent: null,
  );

  /// Currency object for the **Thai Baht** (`THB`; no explicit symbol)
  static final Currency thb = Currency._(
    code: "THB",
    symbol: null,
    exchangeRate: 32.31545316,
    exponent: null,
  );

  /// Currency object for the **Tajikistani Somoni** (`TJS`; no explicit symbol)
  static final Currency tjs = Currency._(
    code: "TJS",
    symbol: null,
    exchangeRate: 9.36098133,
    exponent: null,
  );

  /// Currency object for the **Turkmenistani Manat** (`TMT`; no explicit symbol)
  static final Currency tmt = Currency._(
    code: "TMT",
    symbol: null,
    exchangeRate: 3.50668705,
    exponent: null,
  );

  /// Currency object for the **Tunisian Dinar** (`TND`; no explicit symbol)
  static final Currency tnd = Currency._(
    code: "TND",
    symbol: null,
    exchangeRate: 2.87988422,
    exponent: 3,
  );

  /// Currency object for the **Tongan Paʻanga** (`TOP`; no explicit symbol)
  static final Currency top = Currency._(
    code: "TOP",
    symbol: null,
    exchangeRate: 2.35239391,
    exponent: null,
  );

  /// Currency object for the **Turkish Lira** (`TRY`; no explicit symbol)
  static final Currency kTry = Currency._(
    code: "TRY",
    symbol: null,
    exchangeRate: 40.73159847,
    exponent: null,
  );

  /// Currency object for the **Trinidad & Tobago Dollar** (`TTD`; no explicit symbol)
  static final Currency ttd = Currency._(
    code: "TTD",
    symbol: null,
    exchangeRate: 6.76698392,
    exponent: null,
  );

  /// Currency object for the **New Taiwan Dollar** (`TWD`) with the symbol `NT$`
  static final Currency twd = Currency._(
    code: "TWD",
    symbol: r"NT$",
    exchangeRate: 29.88132349,
    exponent: 2,
  );

  /// Currency object for the **Tanzanian Shilling** (`TZS`; no explicit symbol)
  static final Currency tzs = Currency._(
    code: "TZS",
    symbol: null,
    exchangeRate: 2471.47934324,
    exponent: 2,
  );

  /// Currency object for the **Ukrainian Hryvnia** (`UAH`; no explicit symbol)
  static final Currency uah = Currency._(
    code: "UAH",
    symbol: null,
    exchangeRate: 41.48586327,
    exponent: null,
  );

  /// Currency object for the **Ugandan Shilling** (`UGX`; no explicit symbol)
  static final Currency ugx = Currency._(
    code: "UGX",
    symbol: null,
    exchangeRate: 3565.59925396,
    exponent: 0,
  );

  /// Currency object for the **US Dollar** (`USD`) with the symbol `$`
  static final Currency usd = Currency._(
    code: "USD",
    symbol: r"$",
    exchangeRate: 1,
    exponent: null,
  );

  /// Currency object for the **Uruguayan Peso** (`UYU`; no explicit symbol)
  static final Currency uyu = Currency._(
    code: "UYU",
    symbol: null,
    exchangeRate: 39.97529081,
    exponent: null,
  );

  /// Currency object for the **Uzbekistani Som** (`UZS`; no explicit symbol)
  static final Currency uzs = Currency._(
    code: "UZS",
    symbol: null,
    exchangeRate: 12583.84546451,
    exponent: 2,
  );

  /// Currency object for the **Bolívar Soberano** (`VED`; no explicit symbol)
  static final Currency ved = Currency._(
    code: "VED",
    symbol: null,
    exchangeRate: 130.70150344,
    exponent: null,
  );

  /// Currency object for the **Venezuelan Bolívar** (`VES`; no explicit symbol)
  static final Currency ves = Currency._(
    code: "VES",
    symbol: null,
    exchangeRate: 130.70150344,
    exponent: null,
  );

  /// Currency object for the **Vietnamese Dong** (`VND`) with the symbol `₫`
  static final Currency vnd = Currency._(
    code: "VND",
    symbol: r"₫",
    exchangeRate: 26215.60726445,
    exponent: 0,
  );

  /// Currency object for the **Vanuatu Vatu** (`VUV`; no explicit symbol)
  static final Currency vuv = Currency._(
    code: "VUV",
    symbol: null,
    exchangeRate: 119.40149252,
    exponent: 0,
  );

  /// Currency object for the **Samoan Tala** (`WST`; no explicit symbol)
  static final Currency wst = Currency._(
    code: "WST",
    symbol: null,
    exchangeRate: 2.65391255,
    exponent: null,
  );

  /// Currency object for the **Central African CFA Franc** (`XAF`) with the symbol `FCFA`
  static final Currency xaf = Currency._(
    code: "XAF",
    symbol: r"FCFA",
    exchangeRate: 564.17999169,
    exponent: 0,
  );

  /// Currency object for the **Silver** (`XAG`; no explicit symbol)
  static final Currency xag = Currency._(
    code: "XAG",
    symbol: null,
    exchangeRate: 0.026080977,
    exponent: null,
  );

  /// Currency object for the **Gold** (`XAU`; no explicit symbol)
  static final Currency xau = Currency._(
    code: "XAU",
    symbol: null,
    exchangeRate: 0.0002942607,
    exponent: null,
  );

  /// Currency object for the **East Caribbean Dollar** (`XCD`) with the symbol `EC$`
  static final Currency xcd = Currency._(
    code: "XCD",
    symbol: r"EC$",
    exchangeRate: 2.7001891,
    exponent: null,
  );

  /// Currency object for the **Caribbean guilder** (`XCG`) with the symbol `Cg.`
  static final Currency xcg = Currency._(
    code: "XCG",
    symbol: r"Cg.",
    exchangeRate: 1.79888937,
    exponent: null,
  );

  /// Currency object for the **Special Drawing Rights** (`XDR`; no explicit symbol)
  static final Currency xdr = Currency._(
    code: "XDR",
    symbol: null,
    exchangeRate: 0.73223059,
    exponent: null,
  );

  /// Currency object for the **West African CFA Franc** (`XOF`) with the symbol `F CFA`
  static final Currency xof = Currency._(
    code: "XOF",
    symbol: r"F CFA",
    exchangeRate: 564.17999169,
    exponent: 0,
  );

  /// Currency object for the **Palladium** (`XPD`; no explicit symbol)
  static final Currency xpd = Currency._(
    code: "XPD",
    symbol: null,
    exchangeRate: 0.0008924835,
    exponent: null,
  );

  /// Currency object for the **CFP Franc** (`XPF`) with the symbol `CFPF`
  static final Currency xpf = Currency._(
    code: "XPF",
    symbol: r"CFPF",
    exchangeRate: 102.63566262,
    exponent: 0,
  );

  /// Currency object for the **Platinum** (`XPT`; no explicit symbol)
  static final Currency xpt = Currency._(
    code: "XPT",
    symbol: null,
    exchangeRate: 0.0007496437,
    exponent: null,
  );

  /// Currency object for the **Yemeni Rial** (`YER`; no explicit symbol)
  static final Currency yer = Currency._(
    code: "YER",
    symbol: null,
    exchangeRate: 240.56716377,
    exponent: 0,
  );

  /// Currency object for the **South African Rand** (`ZAR`; no explicit symbol)
  static final Currency zar = Currency._(
    code: "ZAR",
    symbol: null,
    exchangeRate: 17.74246465,
    exponent: null,
  );

  /// Currency object for the **Zambian Kwacha** (`ZMW`; no explicit symbol)
  static final Currency zmw = Currency._(
    code: "ZMW",
    symbol: null,
    exchangeRate: 23.2003755,
    exponent: null,
  );

  /// Currency object for the **Zimbabwean Gold** (`ZWG`; no explicit symbol)
  static final Currency zwg = Currency._(
    code: "ZWG",
    symbol: null,
    exchangeRate: 26.7669559,
    exponent: null,
  );

  static final Set<Currency> currencies = {
    aed,
    afn,
    all,
    amd,
    aoa,
    ars,
    aud,
    awg,
    azn,
    bam,
    bbd,
    bdt,
    bgn,
    bhd,
    bif,
    bmd,
    bnd,
    bob,
    brl,
    bsd,
    btn,
    bwp,
    byn,
    bzd,
    cad,
    cdf,
    chf,
    clp,
    cnh,
    cny,
    cop,
    crc,
    cup,
    cve,
    czk,
    djf,
    dkk,
    dop,
    dzd,
    egp,
    ern,
    etb,
    eur,
    fjd,
    fkp,
    gbp,
    gel,
    ghs,
    gip,
    gmd,
    gnf,
    gtq,
    gyd,
    hkd,
    hnl,
    htg,
    huf,
    idr,
    ils,
    inr,
    iqd,
    irr,
    isk,
    jmd,
    jod,
    jpy,
    kes,
    kgs,
    khr,
    kmf,
    kpw,
    krw,
    kwd,
    kyd,
    kzt,
    lak,
    lbp,
    lkr,
    lrd,
    lsl,
    lyd,
    mad,
    mdl,
    mga,
    mkd,
    mmk,
    mnt,
    mop,
    mru,
    mur,
    mvr,
    mwk,
    mxn,
    mxv,
    myr,
    mzn,
    nad,
    ngn,
    nio,
    nok,
    npr,
    nzd,
    omr,
    pab,
    pen,
    pgk,
    php,
    pkr,
    pln,
    pyg,
    qar,
    ron,
    rsd,
    rub,
    rwf,
    sar,
    sbd,
    scr,
    sdg,
    sek,
    sgd,
    shp,
    sle,
    sos,
    srd,
    stn,
    syp,
    szl,
    thb,
    tjs,
    tmt,
    tnd,
    top,
    kTry,
    ttd,
    twd,
    tzs,
    uah,
    ugx,
    usd,
    uyu,
    uzs,
    ved,
    ves,
    vnd,
    vuv,
    wst,
    xaf,
    xag,
    xau,
    xcd,
    xcg,
    xdr,
    xof,
    xpd,
    xpf,
    xpt,
    yer,
    zar,
    zmw,
    zwg,
  };
  // GENERATION END
}
