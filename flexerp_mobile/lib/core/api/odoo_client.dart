import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, HttpException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OdooException implements Exception {
  final String message;
  final int? code;
  final dynamic data;

  /// True when the request never got a JSON-RPC answer from Odoo
  /// (socket/DNS failure, timeout, HTTP 5xx without a JSON-RPC error body).
  /// Only these failures may be queued for offline replay.
  final bool isNetworkError;

  /// Odoo exception class from `error.data.name`
  /// (e.g. `odoo.exceptions.UserError`, `odoo.exceptions.AccessError`).
  final String? errorName;

  /// HTTP status code when the failure came from a non-200 response.
  final int? httpStatus;

  OdooException(
    this.message, {
    this.code,
    this.data,
    this.isNetworkError = false,
    this.errorName,
    this.httpStatus,
  });

  /// Business / validation / access errors raised by Odoo. These must be
  /// surfaced to the user and never queued for silent retry.
  bool get isBusinessError => !isNetworkError;

  bool get isSessionExpired =>
      errorName?.contains('SessionExpired') == true || code == 100;

  @override
  String toString() => 'OdooException: $message (code: $code)';
}

/// Whether [error] is a transport failure that is safe to queue for replay.
bool isNetworkFailure(Object error) {
  if (error is OdooException) return error.isNetworkError;
  return error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is http.ClientException;
}

/// Human readable message for any error (strips the `OdooException:` prefix).
String describeError(Object error) {
  if (error is OdooException) return error.message;
  return error.toString();
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);
  bool get isFresh => DateTime.now().isBefore(expiresAt);
}

/// Robust JSON-RPC 2.0 client for Odoo 16/17/18/20 + FlexERP mobile facades.
class OdooClient {
  String baseUrl;
  String? sessionId;
  List<int> allowedCompanyIds;
  int? activeCompanyId;
  final Duration timeout;
  final int maxRetries;
  final http.Client _http;
  final Duration cacheTtl;
  final Map<String, _CacheEntry> _cache = {};

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
    http.Client? httpClient,
    this.cacheTtl = const Duration(seconds: 45),
  }) : _http = httpClient ?? http.Client() {
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    if (sessionId != null) {
      updateSession(sessionId!);
    }
  }

  /// New client instance sharing transport + session + company context
  /// (empty cache). Used to publish context changes to Riverpod watchers.
  OdooClient copy() {
    return OdooClient(
      baseUrl: baseUrl,
      sessionId: sessionId,
      allowedCompanyIds: List<int>.from(allowedCompanyIds),
      activeCompanyId: activeCompanyId,
      timeout: timeout,
      maxRetries: maxRetries,
      httpClient: _http,
      cacheTtl: cacheTtl,
    );
  }

  void invalidateCachePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.contains(prefix));
  }

  void clearCache() => _cache.clear();

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

  /// POST a JSON-RPC payload.
  ///
  /// Transport failures and bare HTTP 5xx responses are retried only when
  /// [retry] is true — i.e. for idempotent reads or writes that carry a
  /// client `uuid` the server deduplicates on. Non-idempotent writes are
  /// sent exactly once so a slow-but-successful request is never doubled.
  Future<http.Response> _post(
    Uri uri,
    Map<String, dynamic> payload, {
    bool retry = true,
  }) async {
    final attempts = retry ? maxRetries : 0;
    Object? lastError;
    for (var attempt = 0; attempt <= attempts; attempt++) {
      try {
        final response = await _http
            .post(uri, headers: _headers, body: jsonEncode(payload))
            .timeout(timeout);
        if (response.statusCode >= 500 &&
            attempt < attempts &&
            _jsonRpcError(response.body) == null) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
          continue;
        }
        return response;
      } catch (e) {
        lastError = e;
        if (attempt < attempts) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
          continue;
        }
      }
    }
    throw OdooException(
      lastError is TimeoutException
          ? 'Request timed out — check your connection'
          : 'Network error: $lastError',
      isNetworkError: true,
    );
  }

  static Map<String, dynamic>? _jsonRpcError(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return Map<String, dynamic>.from(decoded['error'] as Map);
      }
    } catch (_) {
      // Not JSON (proxy error page, captive portal…) — caller classifies.
    }
    return null;
  }

  static OdooException _rpcException(Map<String, dynamic> error, {int? httpStatus}) {
    final data = error['data'];
    final dataMap = data is Map ? data : null;
    final message = dataMap?['message']?.toString() ?? error['message']?.toString() ?? 'RPC error';
    final rawCode = error['code'];
    return OdooException(
      message,
      code: rawCode is int ? rawCode : int.tryParse('${rawCode ?? ''}'),
      data: data,
      errorName: dataMap?['name']?.toString(),
      httpStatus: httpStatus,
    );
  }

  dynamic _decodeResult(http.Response response) {
    final rpcError = _jsonRpcError(response.body);
    if (rpcError != null) {
      // Odoo answered with a JSON-RPC error (UserError, ValidationError,
      // AccessError, …) — a business failure, never a network one.
      throw _rpcException(rpcError, httpStatus: response.statusCode);
    }
    if (response.statusCode != 200) {
      throw OdooException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'error'}',
        httpStatus: response.statusCode,
        // Gateway / upstream failures without an Odoo answer are transient.
        isNetworkError: response.statusCode >= 500,
      );
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw OdooException(
        'Unexpected non-JSON response from server',
        httpStatus: response.statusCode,
        isNetworkError: true,
      );
    }
    if (decoded is! Map) {
      throw OdooException('Malformed JSON-RPC response');
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
          isNetworkError: true,
        );
      }
      if (e is OdooException) rethrow;
      throw OdooException('Connection failed: $e', isNetworkError: true);
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
    } catch (e) {
      // Database listing is often disabled (list_db = False); not fatal.
      debugPrint('FlexERP: database list unavailable: $e');
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
  ///
  /// Pass [cacheKey] for short TTL caching of read-heavy list endpoints.
  /// Transport retries happen only when [idempotent] is true, a [cacheKey]
  /// is given (reads), or the params carry a client `uuid` the server
  /// deduplicates on.
  Future<dynamic> callRoute(
    String path, [
    Map<String, dynamic> params = const {},
    String? cacheKey,
    bool idempotent = false,
  ]) async {
    if (cacheKey != null) {
      final hit = _cache[cacheKey];
      if (hit != null && hit.isFresh) return hit.value;
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalized');
    final uuid = params['uuid'];
    final canRetry = idempotent ||
        cacheKey != null ||
        (uuid is String && uuid.isNotEmpty);
    final response = await _post(
      uri,
      {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
        'id': DateTime.now().millisecondsSinceEpoch,
      },
      retry: canRetry,
    );
    final result = _decodeResult(response);
    if (cacheKey != null) {
      _cache[cacheKey] = _CacheEntry(result, DateTime.now().add(cacheTtl));
    }
    return result;
  }

  /// ORM methods that never mutate data and are therefore safe to retry.
  static const Set<String> readOnlyOrmMethods = {
    'search_read',
    'read',
    'search',
    'search_count',
    'name_search',
    'fields_get',
    'read_group',
    'web_search_read',
    'web_read',
  };

  Future<dynamic> callKw({
    required String model,
    required String method,
    required List<dynamic> args,
    Map<String, dynamic> kwargs = const {},
  }) async {
    final uri = Uri.parse('$baseUrl/web/dataset/call_kw');
    final response = await _post(
      uri,
      {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'model': model,
          'method': method,
          'args': args,
          'kwargs': _companyKwargs(kwargs),
        },
        'id': DateTime.now().millisecondsSinceEpoch,
      },
      retry: readOnlyOrmMethods.contains(method),
    );
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
    if (res is List && res.isNotEmpty) return parseOdooInt(res.first) ?? 0;
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

  /// Hosts used during local development (emulator loopback included).
  static const Set<String> devHosts = {'localhost', '127.0.0.1', '10.0.2.2', '::1', '[::1]'};

  static String _hostOf(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return '';
    if (!url.contains('://')) url = 'http://$url';
    return Uri.tryParse(url)?.host ?? '';
  }

  /// True for localhost / loopback / Android-emulator host addresses.
  static bool isDevHost(String rawUrl) => devHosts.contains(_hostOf(rawUrl));

  /// HTTPS is enforced by default for every host except local dev hosts.
  static bool defaultEnforceHttps(String rawUrl) => !isDevHost(rawUrl);

  static String normalizeUrl(String raw, {required bool enforceHttps}) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '${enforceHttps ? 'https' : 'http'}://$url';
    }
    if (enforceHttps && url.startsWith('http://')) {
      url = 'https://${url.substring('http://'.length)}';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static void assertUrlAllowed(String url, {required bool enforceHttps, required bool isRelease}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw OdooException('Invalid server URL');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw OdooException('Unsupported URL scheme: ${uri.scheme}');
    }
    if (enforceHttps && uri.scheme != 'https') {
      throw OdooException('HTTPS is required. Enable HTTPS or disable Enforce HTTPS.');
    }
    if (isRelease && uri.scheme != 'https' && !devHosts.contains(uri.host)) {
      throw OdooException('Release builds require HTTPS for remote servers.');
    }
  }
}

/// Safe int parsing for Odoo JSON values (int, num, numeric string,
/// many2one `[id, name]` pairs). Returns null for `false`/null/garbage.
int? parseOdooInt(dynamic value) {
  if (value == null || value == false) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  if (value is List && value.isNotEmpty) return parseOdooInt(value.first);
  return null;
}
