import 'dart:convert';
import 'package:http/http.dart' as http;

class FetchedProduct {
  final String name;
  final String priceString;
  final double price;

  FetchedProduct({
    required this.name,
    required this.priceString,
    required this.price,
  });

  factory FetchedProduct.fromJson(Map<String, dynamic> json) {
    final priceStr = json['price'] as String;
    final cleanPrice = _extractPrice(priceStr);
    
    return FetchedProduct(
      name: json['name'] as String,
      priceString: priceStr,
      price: cleanPrice,
    );
  }

  static double _extractPrice(String priceString) {
    // Remove currency symbols and commas
    // Example: "₦ 1,500" -> "1500"
    final numericString = priceString.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(numericString) ?? 0.0;
  }
}

class FetchedService {
  static const String apiUrl = 'https://jumia-scraper-xi.vercel.app/api/scrape_jumia';
  
  static Future<List<FetchedProduct>> fetchGroceries() async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final products = data['data']['products'] as List;
          return products
              .map((item) => FetchedProduct.fromJson(item as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch products');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch groceries: $e');
    }
  }

  static Future<List<FetchedProduct>> forceRefresh() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'force_refresh': true}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final products = data['data']['products'] as List;
          return products
              .map((item) => FetchedProduct.fromJson(item as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch products');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to refresh groceries: $e');
    }
  }
}