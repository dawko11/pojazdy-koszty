import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'platform_info.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  static const _tokenKey = 'access_token';
  static const _baseUrlKey = 'api_base_url';
  static const _timeout = Duration(seconds: 8);

  String _baseUrl = defaultBaseUrl();
  String? _token;

  static String defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/$'), '');
    if (kIsWeb) return 'http://localhost:8000';
    if (isAndroidDevice) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  String get baseUrl => _baseUrl;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = (prefs.getString(_baseUrlKey) ?? defaultBaseUrl()).replaceAll(RegExp(r'/$'), '');
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  Future<String?> getToken() async {
    if (_token != null && _token!.isNotEmpty) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    return _json('POST', '/auth/register', body: {'email': email, 'password': password}, auth: false);
  }

  Future<String> login(String email, String password) async {
    final data = await _json('POST', '/auth/login', body: {'email': email, 'password': password}, auth: false);
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Serwer nie zwrócił tokenu');
    }
    await setToken(token);
    return token;
  }

  Future<List<dynamic>> vehicles() => _jsonList('GET', '/vehicles');

  Future<Map<String, dynamic>> createVehicle(Map<String, dynamic> body) {
    return _json('POST', '/vehicles', body: body);
  }

  Future<Map<String, dynamic>> updateVehicle(int id, Map<String, dynamic> body) {
    return _json('PUT', '/vehicles/$id', body: body);
  }

  Future<void> deleteVehicle(int id) => _send('DELETE', '/vehicles/$id');

  Future<List<dynamic>> fuelEntries(int vehicleId) {
    return _jsonList('GET', '/vehicles/$vehicleId/fuel-entries');
  }

  Future<Map<String, dynamic>> createFuel(int vehicleId, Map<String, dynamic> body) {
    return _json('POST', '/vehicles/$vehicleId/fuel-entries', body: body);
  }

  Future<void> deleteFuel(int entryId) => _send('DELETE', '/fuel-entries/$entryId');

  Future<Map<String, dynamic>> stats(int vehicleId) {
    return _json('GET', '/vehicles/$vehicleId/stats');
  }

  Future<List<Map<String, dynamic>>> nearbyStations(double lat, double lon) async {
    final data = await _json('GET', '/stations/nearby?lat=$lat&lon=$lon');
    final list = data['stations'];
    if (list is! List) return [];
    return [for (final item in list) Map<String, dynamic>.from(item as Map)];
  }

  Map<String, dynamic> _asStringMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw ApiException('Nieoczekiwana odpowiedź serwera');
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final response = await _send(method, path, body: body, auth: auth);
    if (response.body.isEmpty) return {};
    return _asStringMap(jsonDecode(response.body));
  }

  Future<List<dynamic>> _jsonList(String method, String path) async {
    final response = await _send(method, path);
    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is List) return List<dynamic>.from(decoded);
    throw ApiException('Nieoczekiwana odpowiedź serwera');
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (auth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response response;
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..followRedirects = true;
      if (encoded != null) {
        request.body = encoded;
      }
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'Przekroczono czas oczekiwania na API ($_baseUrl). Sprawdź, czy kontener api nasłuchuje na porcie 8000.',
      );
    } on FormatException {
      throw ApiException('Nieprawidłowy adres API: $_baseUrl');
    } on http.ClientException {
      throw ApiException('Brak połączenia z API ($_baseUrl). Sprawdź, czy backend działa na porcie 8000.');
    } catch (e) {
      final name = e.runtimeType.toString();
      if (name == 'SocketException' || name == 'HttpException') {
        throw ApiException('Brak połączenia z API ($_baseUrl). Uruchom: docker compose up --build.');
      }
      rethrow;
    }
    if (response.statusCode >= 400) {
      throw ApiException(_errorMessage(response), response.statusCode);
    }
    return response;
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
      if (data is Map && data['detail'] is List) {
        final parts = (data['detail'] as List).map((item) {
          if (item is Map && item['msg'] != null) return item['msg'].toString();
          return item.toString();
        });
        return parts.join('\n');
      }
    } catch (_) {}
    if (response.statusCode == 401) return 'Błędny email lub hasło. Jeśli nie masz konta, użyj rejestracji.';
    return 'Błąd serwera (${response.statusCode})';
  }
}
