// Currency data class
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyData {
  final String code;
  final String symbol;
  final String name;
  final String locale;

  const CurrencyData({
    required this.code,
    required this.symbol,
    required this.name,
    required this.locale,
  });
}

// Available currencies
class AppCurrencies {
  static const List<CurrencyData> currencies = [
    CurrencyData(code: 'USD', symbol: '\$', name: 'US Dollar', locale: 'en_US'),
    CurrencyData(code: 'EUR', symbol: '€', name: 'Euro', locale: 'de_DE'),
    CurrencyData(code: 'GBP', symbol: '£', name: 'British Pound', locale: 'en_GB'),
    CurrencyData(code: 'JPY', symbol: '¥', name: 'Japanese Yen', locale: 'ja_JP'),
    CurrencyData(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', locale: 'zh_CN'),
    CurrencyData(code: 'INR', symbol: '₹', name: 'Indian Rupee', locale: 'en_IN'),
    CurrencyData(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', locale: 'en_AU'),
    CurrencyData(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', locale: 'en_CA'),
    CurrencyData(code: 'CHF', symbol: 'Fr', name: 'Swiss Franc', locale: 'de_CH'),
    CurrencyData(code: 'SEK', symbol: 'kr', name: 'Swedish Krona', locale: 'sv_SE'),
    CurrencyData(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar', locale: 'en_NZ'),
    CurrencyData(code: 'NGN', symbol: '₦', name: 'Nigerian Naira', locale: 'en_NG'),
    CurrencyData(code: 'KRW', symbol: '₩', name: 'South Korean Won', locale: 'ko_KR'),
    CurrencyData(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', locale: 'en_SG'),
    CurrencyData(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone', locale: 'nb_NO'),
    CurrencyData(code: 'MXN', symbol: 'Mex\$', name: 'Mexican Peso', locale: 'es_MX'),
    CurrencyData(code: 'ZAR', symbol: 'R', name: 'South African Rand', locale: 'en_ZA'),
    CurrencyData(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real', locale: 'pt_BR'),
    CurrencyData(code: 'RUB', symbol: '₽', name: 'Russian Ruble', locale: 'ru_RU'),
    CurrencyData(code: 'TRY', symbol: '₺', name: 'Turkish Lira', locale: 'tr_TR'),
    CurrencyData(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', locale: 'ar_AE'),
  ];

  static CurrencyData getCurrency(String code) {
    return currencies.firstWhere(
      (c) => c.code == code,
      orElse: () => currencies[0], // Default to USD
    );
  }
}

// Currency provider
final currencyProvider = StateNotifierProvider<CurrencyNotifier, CurrencyData>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<CurrencyData> {
  CurrencyNotifier() : super(AppCurrencies.currencies[0]) {
    _loadCurrency();
  }

  static const String _currencyKey = 'selected_currency';

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final currencyCode = prefs.getString(_currencyKey) ?? 'USD';
    state = AppCurrencies.getCurrency(currencyCode);
  }

  Future<void> setCurrency(CurrencyData currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currency.code);
  }
}

// Currency formatter provider
final currencyFormatterProvider = Provider<NumberFormat>((ref) {
  final currency = ref.watch(currencyProvider);
  return NumberFormat.currency(
    locale: currency.locale,
    symbol: currency.symbol,
    decimalDigits: currency.code == 'JPY' || currency.code == 'KRW' ? 0 : 2,
  );
});

// Helper extension for easy formatting
extension CurrencyFormatting on double {
  String formatCurrency(NumberFormat formatter) {
    return formatter.format(this);
  }
}