import 'package:flutter_test/flutter_test.dart';
import 'package:flexerp_mobile/core/api/odoo_client.dart';
import 'package:flexerp_mobile/core/storage/secure_session_store.dart';
import 'package:flexerp_mobile/data/repositories/auth_repository.dart';
import 'package:flexerp_mobile/data/repositories/pos_repository.dart';

void main() {
  group('parseSessionCompany', () {
    test('Odoo 17+: current_company is an int, name from allowed_companies', () {
      final c = parseSessionCompany({
        'uid': 2,
        'user_companies': {
          'current_company': 3,
          'allowed_companies': {
            '3': {'id': 3, 'name': 'Kandy Hardware'},
            '1': {'id': 1, 'name': 'HQ'},
          },
        },
      });
      expect(c.id, 3);
      expect(c.name, 'Kandy Hardware');
    });

    test('legacy: current_company is [id, name]', () {
      final c = parseSessionCompany({
        'user_companies': {
          'current_company': [2, 'Colombo Traders'],
          'allowed_companies': [
            [2, 'Colombo Traders'],
          ],
        },
      });
      expect(c.id, 2);
      expect(c.name, 'Colombo Traders');
    });

    test('company_id takes precedence and missing data is tolerated', () {
      expect(parseSessionCompany({'company_id': 7}).id, 7);
      final empty = parseSessionCompany({});
      expect(empty.id, isNull);
      expect(empty.name, isNull);
    });
  });

  test('parseOdooInt handles int, num, string, many2one and false', () {
    expect(parseOdooInt(5), 5);
    expect(parseOdooInt(5.0), 5);
    expect(parseOdooInt('42'), 42);
    expect(parseOdooInt([9, 'Name']), 9);
    expect(parseOdooInt(false), isNull);
    expect(parseOdooInt(null), isNull);
    expect(parseOdooInt('abc'), isNull);
  });

  test('parseLiveLastEventId', () {
    expect(parseLiveLastEventId({'live_last_event_id': 120}), 120);
    expect(parseLiveLastEventId({'live_last_event_id': 0}), isNull);
    expect(parseLiveLastEventId(null), isNull);
  });

  test('normalizePosOrderResult accepts new `id` and legacy `order_id`', () {
    final modern = normalizePosOrderResult(
      {'id': 11, 'name': 'Shop/0011', 'uuid': 'u-1', 'amount_total': 205.0, 'amount_tax': 30.0},
      fallbackUuid: 'x',
    );
    expect(modern['order_id'], 11);
    expect(modern['amount_tax'], 30.0);
    expect(modern['queued'], isFalse);
    final legacy = normalizePosOrderResult({'order_id': 12}, fallbackUuid: 'fallback');
    expect(legacy['id'], 12);
    expect(legacy['uuid'], 'fallback');
  });

  test('newPosOrderUuid is RFC 4122 v4 and unique', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final a = newPosOrderUuid();
    final b = newPosOrderUuid();
    expect(re.hasMatch(a), isTrue, reason: a);
    expect(a, isNot(b));
  });

  test('StoredSession.fromJson tolerates numeric strings', () {
    final s = StoredSession.fromJson({
      'serverUrl': 'https://erp.example.lk',
      'database': 'db',
      'sessionId': 'sid',
      'uid': '4',
      'companyId': 2.0,
    });
    expect(s.uid, 4);
    expect(s.companyId, 2);
  });

  group('URL policy', () {
    test('HTTPS enforced by default except dev hosts', () {
      expect(OdooClient.defaultEnforceHttps('erp.example.lk'), isTrue);
      expect(OdooClient.defaultEnforceHttps('https://erp.example.lk/'), isTrue);
      expect(OdooClient.defaultEnforceHttps('http://localhost:8069'), isFalse);
      expect(OdooClient.defaultEnforceHttps('127.0.0.1:8069'), isFalse);
      expect(OdooClient.defaultEnforceHttps('http://10.0.2.2:8069'), isFalse);
    });

    test('release builds reject http for remote hosts only', () {
      expect(
        () => OdooClient.assertUrlAllowed('http://erp.example.lk', enforceHttps: false, isRelease: true),
        throwsA(isA<OdooException>()),
      );
      OdooClient.assertUrlAllowed('http://10.0.2.2:8069', enforceHttps: false, isRelease: true);
      OdooClient.assertUrlAllowed('https://erp.example.lk', enforceHttps: true, isRelease: true);
    });
  });
}
