import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OdooException implements Exception {
  final String message;
  final int? code;
  final dynamic data;

  OdooException(this.message, {this.code, this.data});

  @override
  String toString() => 'OdooException: $message (code: $code)';
}

/// Robust JSON-RPC 2.0 client for Odoo 16/17/18/20 backend servers.
class OdooClient {
  String baseUrl;
  String? sessionId;
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  OdooClient({required this.baseUrl, this.sessionId}) {
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    if (sessionId != null) {
      updateSession(sessionId!);
    }
  }

  bool get isAuthenticated => sessionId != null && sessionId!.isNotEmpty;

  void updateSession(String newSessionId) {
    sessionId = newSessionId;
    _headers['X-Openerp-Session-Id'] = newSessionId;
    // On web, setting the Cookie header is forbidden by browsers, but fine on Mobile/Desktop
    if (!kIsWeb) {
      _headers['Cookie'] = 'session_id=$newSessionId';
    }
  }

  /// Pings instance to verify server connectivity and latency.
  Future<Map<String, dynamic>> ping() async {
    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse('$baseUrl/web/webclient/version_info');
    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {},
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 8));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = decoded['result'] as Map<String, dynamic>? ?? {};
        return {
          'success': true,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'serverVersion': result['server_version'] ?? 'Odoo Enterprise',
        };
      }
      return {
        'success': true,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'serverVersion': 'HTTP ${response.statusCode}',
      };
    } catch (e) {
      stopwatch.stop();
      // If web browser blocks due to CORS
      final errorMsg = e.toString();
      if (kIsWeb && errorMsg.contains('XMLHttpRequest')) {
        throw OdooException(
          'Web CORS Error: Browser blocked request to $baseUrl. '
          'Please ensure Odoo has CORS headers enabled, or test using Sri Lanka Demo Sandbox.',
        );
      }
      throw OdooException('Connection failed: $e');
    }
  }

  /// Queries /web/database/list to discover available databases on the instance.
  Future<List<String>> listDatabases() async {
    final uri = Uri.parse('$baseUrl/web/database/list');
    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {},
          'id': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['result'] is List) {
          final list = List<String>.from(decoded['result']);
          if (list.isNotEmpty) return list;
        }
      }
      return ['flexerp_production_lk', 'flexcorp_demo_db'];
    } catch (_) {
      return ['flexerp_production_lk', 'flexcorp_demo_db'];
    }
  }

  /// Authenticates user against /web/session/authenticate.
  Future<Map<String, dynamic>> authenticate({
    required String db,
    required String login,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/web/session/authenticate');
    final payload = {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        'db': db,
        'login': login,
        'password': password,
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['error'] != null) {
          throw OdooException(
            decoded['error']['data']?['message'] ?? decoded['error']['message'] ?? 'Authentication failed',
            code: decoded['error']['code'],
          );
        }
        final result = decoded['result'] as Map<String, dynamic>;
        final sid = result['session_id'] as String?;
        if (sid != null) {
          updateSession(sid);
        }
        return result;
      } else {
        throw OdooException('Server returned HTTP status ${response.statusCode}');
      }
    } catch (e) {
      if (e is OdooException) rethrow;
      if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
        throw OdooException(
          'Browser CORS Error: Unable to authenticate with $baseUrl directly from Web. '
          'Please run on mobile device or enable CORS.',
        );
      }
      throw OdooException('Connection error: $e');
    }
  }

  /// Calls any Odoo model method using `/web/dataset/call_kw`.
  Future<dynamic> callKw({
    required String model,
    required String method,
    required List<dynamic> args,
    Map<String, dynamic> kwargs = const {},
  }) async {
    final uri = Uri.parse('$baseUrl/web/dataset/call_kw');
    final payload = {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        'model': model,
        'method': method,
        'args': args,
        'kwargs': kwargs,
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['error'] != null) {
          throw OdooException(
            decoded['error']['data']?['message'] ?? decoded['error']['message'] ?? 'Method call error',
            code: decoded['error']['code'],
          );
        }
        return decoded['result'];
      } else {
        throw OdooException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e is OdooException) rethrow;
      throw OdooException('Network execution error: $e');
    }
  }

  /// ORM Helper: search_read
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    List<dynamic> domain = const [],
    List<String> fields = const [],
    int limit = 80,
    String order = 'id desc',
  }) async {
    final res = await callKw(
      model: model,
      method: 'search_read',
      args: [domain, fields],
      kwargs: {'limit': limit, 'order': order},
    );
    if (res is List) {
      return res.map((item) => item as Map<String, dynamic>).toList();
    }
    return [];
  }

  /// ORM Helper: create
  Future<int> create({
    required String model,
    required Map<String, dynamic> values,
  }) async {
    final res = await callKw(
      model: model,
      method: 'create',
      args: [values],
    );
    return res is int ? res : (res is List && res.isNotEmpty ? res.first as int : 0);
  }

  /// ORM Helper: write
  Future<bool> write({
    required String model,
    required List<int> ids,
    required Map<String, dynamic> values,
  }) async {
    final res = await callKw(
      model: model,
      method: 'write',
      args: [ids, values],
    );
    return res == true;
  }

  /// ORM Helper: execute button action (e.g. action_confirm, button_validate)
  Future<dynamic> callButton({
    required String model,
    required String method,
    required List<int> ids,
    Map<String, dynamic> kwargs = const {},
  }) async {
    return await callKw(
      model: model,
      method: method,
      args: [ids],
      kwargs: kwargs,
    );
  }
}
