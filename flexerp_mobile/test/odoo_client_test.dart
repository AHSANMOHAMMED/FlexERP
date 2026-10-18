import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flexerp_mobile/core/api/flexerp_mobile_api.dart';
import 'package:flexerp_mobile/core/api/odoo_client.dart';

http.Response _rpcError(String name, String message, {int status = 200}) => http.Response(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {
          'code': 200,
          'message': 'Odoo Server Error',
          'data': {'name': name, 'message': message, 'debug': '...'},
        },
      }),
      status,
      headers: {'content-type': 'application/json'},
    );

OdooClient _client(MockClient mock, {int maxRetries = 0, Duration? timeout}) => OdooClient(
      baseUrl: 'https://erp.example.lk',
      sessionId: 'sid',
      httpClient: mock,
      maxRetries: maxRetries,
      timeout: timeout ?? const Duration(seconds: 5),
    );

Future<OdooException> _capture(Future<dynamic> f) async {
  try {
    await f;
  } on OdooException catch (e) {
    return e;
  }
  fail('expected OdooException');
}

void main() {
  group('error classification', () {
    test('JSON-RPC UserError is a business error (not network)', () async {
      final c = _client(MockClient((_) async => _rpcError('odoo.exceptions.UserError', 'Insufficient stock')));
      final e = await _capture(c.callRoute('/flexerp/mobile/pos/order', {'uuid': 'u'}));
      expect(e.isNetworkError, isFalse);
      expect(e.isBusinessError, isTrue);
      expect(e.errorName, 'odoo.exceptions.UserError');
      expect(e.message, 'Insufficient stock');
      expect(isNetworkFailure(e), isFalse);
    });

    test('HTTP 500 carrying a JSON-RPC AccessError body is still business', () async {
      final c = _client(MockClient((_) async => _rpcError('odoo.exceptions.AccessError', 'Denied', status: 500)));
      final e = await _capture(c.callRoute('/x', {}));
      expect(e.isNetworkError, isFalse);
      expect(e.errorName, 'odoo.exceptions.AccessError');
    });

    test('HTTP 502 without JSON-RPC body is a network error', () async {
      final c = _client(MockClient((_) async => http.Response('<html>Bad gateway</html>', 502)));
      final e = await _capture(c.callRoute('/x', {}));
      expect(e.isNetworkError, isTrue);
      expect(e.httpStatus, 502);
    });

    test('socket / client exception is a network error', () async {
      final c = _client(MockClient((_) async => throw http.ClientException('Connection refused')));
      final e = await _capture(c.callRoute('/x', {}));
      expect(e.isNetworkError, isTrue);
      expect(isNetworkFailure(e), isTrue);
    });

    test('timeout is a network error', () async {
      final c = _client(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 20),
      );
      final e = await _capture(c.callRoute('/x', {}));
      expect(e.isNetworkError, isTrue);
    });

    test('HTTP 404 without body is neither queued nor network', () async {
      final c = _client(MockClient((_) async => http.Response('not found', 404)));
      final e = await _capture(c.callRoute('/x', {}));
      expect(e.isNetworkError, isFalse);
    });

    test('isNetworkFailure on raw exceptions', () {
      expect(isNetworkFailure(TimeoutException('t')), isTrue);
      expect(isNetworkFailure(http.ClientException('x')), isTrue);
      expect(isNetworkFailure(StateError('x')), isFalse);
    });
  });

  group('retry policy', () {
    late int calls;
    MockClient failing() => MockClient((_) async {
          calls++;
          throw http.ClientException('offline');
        });

    setUp(() => calls = 0);

    test('non-idempotent POST without uuid is sent exactly once', () async {
      final c = _client(failing(), maxRetries: 1);
      await _capture(c.callRoute('/flexerp/mobile/payment/register', {'move_id': 1}));
      expect(calls, 1);
    });

    test('write carrying a uuid may be retried (server dedups)', () async {
      final c = _client(failing(), maxRetries: 1);
      await _capture(c.callRoute('/flexerp/mobile/pos/order', {'uuid': 'abc'}));
      expect(calls, 2);
    });

    test('read-only API routes are retried', () async {
      final c = _client(failing(), maxRetries: 1);
      await _capture(FlexerpMobileApi(c).posConfigs());
      expect(calls, 2);
    });

    test('mutating API routes are not retried', () async {
      final c = _client(failing(), maxRetries: 1);
      await _capture(FlexerpMobileApi(c).hrAttendance(checkIn: true));
      expect(calls, 1);
    });

    test('ORM writes are not retried, reads are', () async {
      final c = _client(failing(), maxRetries: 1);
      await _capture(c.callKw(model: 'res.partner', method: 'write', args: [[1], {}]));
      expect(calls, 1);
      calls = 0;
      await _capture(c.searchRead(model: 'res.partner'));
      expect(calls, 2);
    });

    test('a business error is never retried', () async {
      var n = 0;
      final c = _client(
        MockClient((_) async {
          n++;
          return _rpcError('odoo.exceptions.ValidationError', 'bad');
        }),
        maxRetries: 2,
      );
      await _capture(c.callRoute('/flexerp/mobile/pos/order', {'uuid': 'abc'}));
      expect(n, 1);
    });
  });

  test('no X-Odoo-Company-Ids header; company context goes in kwargs', () async {
    late http.Request captured;
    final c = _client(MockClient((req) async {
      captured = req;
      return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': []}), 200);
    }));
    c.setCompanyContext(companyId: 3, allowedIds: [3, 4]);
    await c.searchRead(model: 'res.partner');
    expect(captured.headers.keys.map((k) => k.toLowerCase()), isNot(contains('x-odoo-company-ids')));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['params']['kwargs']['context']['allowed_company_ids'], [3, 4]);
  });

  test('hrAttendance sends the device timestamp', () async {
    late Map<String, dynamic> params;
    final c = _client(MockClient((req) async {
      params = (jsonDecode(req.body) as Map<String, dynamic>)['params'] as Map<String, dynamic>;
      return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': {'id': 1}}), 200);
    }));
    await FlexerpMobileApi(c).hrAttendance(checkIn: true, timestamp: '2026-10-18 04:30:00');
    expect(params['timestamp'], '2026-10-18 04:30:00');
    expect(params.containsKey('latitude'), isFalse);
  });
}
