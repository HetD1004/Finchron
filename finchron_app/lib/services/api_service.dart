import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';

class ApiService {
  static const String _computerIP = '192.168.29.84';

  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://$_computerIP:3000/api/v1';
    } else if (Platform.isIOS) {
      return 'http://$_computerIP:3000/api/v1';
    } else {
      return 'http://localhost:3000/api/v1';
    }
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'An error occurred');
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String name,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: json.encode({'email': email, 'name': name, 'password': password}),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: json.encode({'email': email, 'password': password}),
    );

    final result = _handleResponse(response);

    // Store the token if login is successful
    if (result['token'] != null) {
      setAuthToken(result['token']);
    }

    return result;
  }

  Future<Map<String, dynamic>> googleLogin({required String idToken}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: _headers,
      body: json.encode({'idToken': idToken}),
    );

    final result = _handleResponse(response);

    if (result['token'] != null) {
      setAuthToken(result['token']);
    }

    return result;
  }

  Future<void> logout() async {
    await http.post(Uri.parse('$baseUrl/auth/logout'), headers: _headers);

    clearAuthToken();
  }

  Future<List<Transaction>> getTransactions({
    int? limit,
    int? offset,
    String? category,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};

    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (category != null) queryParams['category'] = category;
    if (type != null) queryParams['type'] = type;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = Uri.parse(
      '$baseUrl/transactions',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: _headers);
    final result = _handleResponse(response);

    final List<dynamic> transactionsData = result['transactions'];
    return transactionsData.map((data) => Transaction.fromJson(data)).toList();
  }

  Future<Transaction> createTransaction({
    required double amount,
    required String type,
    required String category,
    required String description,
    required DateTime date,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers,
      body: json.encode({
        'amount': amount,
        'type': type,
        'category': category,
        'description': description,
        'date': date.toIso8601String(),
      }),
    );

    final result = _handleResponse(response);
    return Transaction.fromJson(result['transaction']);
  }

  Future<Transaction> updateTransaction({
    required String id,
    double? amount,
    String? type,
    String? category,
    String? description,
    DateTime? date,
  }) async {
    final body = <String, dynamic>{};

    if (amount != null) body['amount'] = amount;
    if (type != null) body['type'] = type;
    if (category != null) body['category'] = category;
    if (description != null) body['description'] = description;
    if (date != null) body['date'] = date.toIso8601String();

    final response = await http.put(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: _headers,
      body: json.encode(body),
    );

    final result = _handleResponse(response);
    return Transaction.fromJson(result['transaction']);
  }

  Future<void> deleteTransaction(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: _headers,
    );

    _handleResponse(response);
  }

  Future<Map<String, dynamic>> getAnalyticsSummary({
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = Uri.parse(
      '$baseUrl/analytics/summary',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getCategoryAnalytics({
    String? startDate,
    String? endDate,
    String? type,
  }) async {
    final queryParams = <String, String>{};

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (type != null) queryParams['type'] = type;

    final uri = Uri.parse(
      '$baseUrl/analytics/categories',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getTrends({String? period, String? type}) async {
    final queryParams = <String, String>{};

    if (period != null) queryParams['period'] = period;
    if (type != null) queryParams['type'] = type;

    final uri = Uri.parse(
      '$baseUrl/analytics/trends',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/dashboard'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  Future<bool> testConnection() async {
    try {
      // First try with the configured URL
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      // fallback to localhost for Android emulator
    }

    if (Platform.isAndroid) {
      try {
        final fallbackResponse = await http
            .get(
              Uri.parse('http://10.0.2.2:3000/api/v1/health'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 15));

        if (fallbackResponse.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('❌ Fallback connection also failed: $e');
      }
    }

    print('❌ All connection attempts failed');
    print('API URL attempted: $baseUrl');
    return false;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
