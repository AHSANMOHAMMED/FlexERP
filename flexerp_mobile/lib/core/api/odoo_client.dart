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

/// Robust JSON-RPC 2.0 client for Odoo 16/17/18/20 + FlexERP mobile facades.
class OdooClient {
  String baseUrl;
  String? sessionId;
  List<int> allowedCompanyIds;
  int? activeCompanyId;
  final Duration timeout;
  final int maxRetries;

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  OdooClient({
    required this.baseUrl,
    this.sessionId,
    this.allowedCompanyIds = const [],
    this.activeCompanyId,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
  }) {
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
    if (!kIsWeb) {
      _headers['Cookie'] = 'session_id=$newSessionId';
    }
  }

  void clearSession() {
    sessionId = null;
    _headers.remove('X-Openerp-Session-Id');
    _headers.remove('Cookie');
  }

  void setCompanyContext({required int companyId, List<int>? allowedIds}) {
    activeCompanyId = companyId;
    if (allowedIds != null) {
      allowedCompanyIds = allowedIds;
    } else if (!allowedCompanyIds.contains(companyId)) {
      allowedCompanyIds = [...allowedCompanyIds, companyId];
    }
    final cids = (allowedCompanyIds.isEmpty ? [companyId] : allowedCompanyIds).join(',');
    _headers['X-Odoo-Company-Ids'] = cids;
  }

  Map<String, dynamic> _companyKwargs([Map<String, dynamic>? kwargs]) {
    final merged = Map<String, dynamic>.from(kwargs ?? {});
    if (activeCompanyId != null) {
      final context = Map<String, dynamic>.from(
        (merged['context'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      context['allowed_company_ids'] =
          allowedCompanyIds.isEmpty ? [activeCompanyId] : allowedCompanyIds;
      context['company_id'] = activeCompanyId;
      merged['context'] = context;
    }
    return merged;
  }

  Future<http.Response> _post(Uri uri, Map<String, dynamic> payload) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(uri, headers: _headers, body: jsonEncode(payload))
            .timeout(timeout);
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
          continue;
        }
        return response;
      } catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
          continue;
        }
      }
    }
    throw OdooException('Network error after retries: $lastError');
  }

  dynamic _decodeResult(http.Response response) {
    if (response.statusCode != 200) {
      throw OdooException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded['error'] != null) {
      throw OdooException(
        decoded['error']['data']?['message'] ??
            decoded['error']['message'] ??
            'RPC error',
        code: decoded['error']['code'],
        data: decoded['error']['data'],
      );
    }
    return decoded['result'];
  }

  Future<Map<String, dynamic>> ping() async {
    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse('$baseUrl/web/webclient/version_info');
    try {
      final response = await _post(uri, {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {},
        'id': DateTime.now().millisecondsSinceEpoch,
      });
      stopwatch.stop();
      final result = _decodeResult(response);
      final map = result is Map<String, dynamic> ? result : <String, dynamic>{};
      return {
        'success': true,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'serverVersion': map['server_version'] ?? 'Odoo',
      };
    } catch (e) {
      stopwatch.stop();
      if (kIsWeb && e.toString().contains('XMLHttpRequest')) {
        throw OdooException(
          'Web CORS Error: Browser blocked request to $baseUrl. '
          'Enable CORS on Odoo or use the Sri Lanka Demo Sandbox.',
        );
      }
      if (e is OdooException) rethrow;
      throw OdooException('Connection failed: $e');
    }
  }

  Future<List<String>> listDatabases() async {
    final uri = Uri.parse('$baseUrl/web/database/list');
    try {
      final response = await _post(uri, {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {},
        'id': DateTime.now().millisecondsSinceEpoch,
      });
      final result = _decodeResult(response);
      if (result is List && result.isNotEmpty) {
        return List<String>.from(result);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> authenticate({
    required String db,
    required String login,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/web/session/authenticate');
    final response = await _post(uri, {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {'db': db, 'login': login, 'password': password},
      'id': DateTime.now().millisecondsSinceEpoch,
    });
    final result = _decodeResult(response);
    if (result is! Map<String, dynamic>) {
      throw OdooException('Unexpected authenticate payload');
    }
    if (result['uid'] == null || result['uid'] == false) {
      throw OdooException('Invalid credentials');
    }
    final sid = result['session_id'] as String?;
    if (sid != null) {
      updateSession(sid);
    } else {
      // Cookie-based sessions may omit session_id in body; keep any Set-Cookie parsing light
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final match = RegExp(r'session_id=([^;]+)').firstMatch(setCookie);
        if (match != null) updateSession(match.group(1)!);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getSessionInfo() async {
    final uri = Uri.parse('$baseUrl/web/session/get_session_info');
    final response = await _post(uri, {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {},
      'id': DateTime.now().millisecondsSinceEpoch,
    });
    final result = _decodeResult(response);
    return result is Map<String, dynamic> ? result : {};
  }

  Future<void> destroySession() async {
    if (!isAuthenticated) {
      clearSession();
      return;
    }
    try {
      final uri = Uri.parse('$baseUrl/web/session/destroy');
      await _post(uri, {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {},
        'id': DateTime.now().millisecondsSinceEpoch,
      });
    } finally {
      clearSession();
    }
  }

  /// Call a FlexERP / Odoo JSON-RPC controller route (e.g. /flexerp/mobile/bootstrap).
  Future<dynamic> callRoute(String path, [Map<String, dynamic> params = const {}]) async {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalized');
    final response = await _post(uri, {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params,
      'id': DateTime.now().millisecondsSinceEpoch,
    });
    return _decodeResult(response);
  }

  Future<dynamic> callKw({
    required String model,
    required String method,
    required List<dynamic> args,
    Map<String, dynamic> kwargs = const {},
  }) async {
    final uri = Uri.parse('$baseUrl/web/dataset/call_kw');
    final response = await _post(uri, {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        'model': model,
        'method': method,
        'args': args,
        'kwargs': _companyKwargs(kwargs),
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    });
    return _decodeResult(response);
  }

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
      args: [],
      kwargs: {
        'domain': domain,
        'fields': fields,
        'limit': limit,
        'order': order,
      },
    );
    if (res is List) {
      return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  Future<int> create({
    required String model,
    required Map<String, dynamic> values,
  }) async {
    final res = await callKw(model: model, method: 'create', args: [values]);
    if (res is int) return res;
    if (res is List && res.isNotEmpty) return res.first as int;
    return 0;
  }

  Future<bool> write({
    required String model,
    required List<int> ids,
    required Map<String, dynamic> values,
  }) async {
    final res = await callKw(model: model, method: 'write', args: [ids, values]);
    return res == true;
  }

  Future<dynamic> callButton({
    required String model,
    required String method,
    required List<int> ids,
    Map<String, dynamic> kwargs = const {},
  }) async {
    return callKw(model: model, method: method, args: [ids], kwargs: kwargs);
  }

  static String normalizeUrl(String raw, {required bool enforceHttps}) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '${enforceHttps ? 'https' : 'http'}://$url';
    }
    if (enforceHttps && url.startsWith('http://')) {
      url = 'https://${url.substring('http://'.length)}';
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  static void assertUrlAllowed(String url, {required bool enforceHttps, required bool isRelease}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw OdooException('Invalid server URL');
    }
    if (enforceHttps && uri.scheme != 'https') {
      throw OdooException('HTTPS is required. Enable HTTPS or disable Enforce HTTPS.');
    }
    if (isRelease && uri.scheme != 'https' && uri.host != 'localhost' && uri.host != '127.0.0.1') {
      throw OdooException('Release builds require HTTPS for remote servers.');
    }
  }
}
