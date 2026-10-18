import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flexerp_mobile/core/api/flexerp_mobile_api.dart';
import 'package:flexerp_mobile/core/api/odoo_client.dart';
import 'package:flexerp_mobile/core/offline/offline_queue.dart';
import 'package:flexerp_mobile/data/models/auth_user.dart';
import 'package:flexerp_mobile/data/repositories/auth_repository.dart';

const _user = AuthUser(
  uid: 7,
  name: 'Cashier',
  email: 'cashier@example.lk',
  role: UserRole.posCashier,
  serverUrl: 'https://erp.example.lk',
  database: 'prod',
  companyId: 2,
  companyName: 'Kandy',
  groups: [],
  sessionId: 'sid',
);

class _FakeUserNotifier extends CurrentUserNotifier {
  @override
  AuthUser? build() => _user;
}

/// Scriptable Odoo backend: 'ok' | 'network' | 'business'.
class _Backend {
  String mode = 'ok';
  final requests = <Map<String, dynamic>>[];

  MockClient get client => MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        requests.add({'path': req.url.path, ...?(body['params'] as Map?)?.cast<String, dynamic>()});
        switch (mode) {
          case 'network':
            throw http.ClientException('offline');
          case 'business':
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'error': {
                  'code': 200,
                  'message': 'Odoo Server Error',
                  'data': {'name': 'odoo.exceptions.UserError', 'message': 'Insufficient stock'},
                },
              }),
              200,
            );
          default:
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'result': {'id': 99, 'uuid': body['params']?['uuid'], 'amount_total': 100.0},
              }),
              200,
            );
        }
      });
}

void main() {
  late _Backend backend;
  late InMemoryOfflineQueueStorage storage;
  late ProviderContainer container;

  ProviderContainer build() {
    final api = FlexerpMobileApi(OdooClient(
      baseUrl: _user.serverUrl,
      sessionId: 'sid',
      httpClient: backend.client,
      maxRetries: 0,
    ));
    return ProviderContainer(overrides: [
      currentUserProvider.overrideWith(_FakeUserNotifier.new),
      flexerpApiProvider.overrideWithValue(api),
      offlineQueueStorageProvider.overrideWithValue(storage),
    ]);
  }

  setUp(() {
    backend = _Backend();
    storage = InMemoryOfflineQueueStorage();
    container = build();
  });
  tearDown(() => container.dispose());

  OfflineQueueNotifier queue() => container.read(offlineQueueProvider.notifier);

  Future<void> ready() async {
    container.read(offlineQueueProvider);
    await queue().ready;
  }

  Map<String, dynamic> posPayload(String uuid) => {
        'session_id': 5,
        'uuid': uuid,
        'lines': [
          {'product_id': 1, 'qty': 1.0, 'price_unit': 100.0, 'discount': 10.0},
        ],
      };

  test('items are scoped to server/db/user/company; only current scope replays', () async {
    await ready();
    await queue().enqueue(type: 'pos_order', payload: posPayload('mine'));
    await queue().enqueue(
      type: 'pos_order',
      payload: posPayload('other-company'),
      scope: const OfflineQueueScope(
        serverUrl: 'https://erp.example.lk',
        database: 'prod',
        uid: 7,
        companyId: 3,
      ),
    );
    await queue().enqueue(
      type: 'pos_order',
      payload: posPayload('other-server'),
      scope: const OfflineQueueScope(
        serverUrl: 'https://other.example.lk',
        database: 'prod',
        uid: 7,
        companyId: 2,
      ),
    );
    expect(queue().pendingForCurrentScope.map((i) => i.uuid), ['mine']);

    final sent = await queue().flush();
    expect(sent, 1);
    expect(backend.requests.map((r) => r['uuid']), ['mine']);
    final remaining = container.read(offlineQueueProvider).map((i) => i.uuid).toList();
    expect(remaining, containsAll(['other-company', 'other-server']));
    expect(remaining, isNot(contains('mine')));
  });

  test('network failures beyond max attempts move to the failed list (not deleted)', () async {
    await ready();
    backend.mode = 'network';
    await queue().enqueue(type: 'pos_order', payload: posPayload('u1'));
    for (var i = 0; i < OfflineQueueNotifier.maxAttempts; i++) {
      await queue().flush();
    }
    final items = container.read(offlineQueueProvider);
    expect(items, hasLength(1));
    expect(items.single.isFailed, isTrue);
    expect(items.single.attempts, OfflineQueueNotifier.maxAttempts);
    expect(queue().failedForCurrentScope, hasLength(1));
    expect(queue().pendingForCurrentScope, isEmpty);

    // Persisted, so it survives restarts.
    expect(storage.value, contains('"status":"failed"'));

    // Further flushes do not touch failed items.
    backend.requests.clear();
    await queue().flush();
    expect(backend.requests, isEmpty);
  });

  test('business error on replay goes straight to failed and keeps the message', () async {
    await ready();
    backend.mode = 'business';
    await queue().enqueue(type: 'pos_order', payload: posPayload('u2'));
    await queue().flush();
    final item = container.read(offlineQueueProvider).single;
    expect(item.isFailed, isTrue);
    expect(item.attempts, 1);
    expect(item.lastError, contains('Insufficient stock'));
  });

  test('uuid is reused: dedup on enqueue and identical on every replay', () async {
    await ready();
    await queue().enqueue(type: 'pos_order', payload: posPayload('same-uuid'));
    await queue().enqueue(type: 'pos_order', payload: posPayload('same-uuid'));
    expect(container.read(offlineQueueProvider), hasLength(1));

    backend.mode = 'network';
    await queue().flush();
    await queue().flush();
    backend.mode = 'ok';
    await queue().flush();

    expect(backend.requests, hasLength(3));
    expect(backend.requests.map((r) => r['uuid']).toSet(), {'same-uuid'});
    expect(container.read(offlineQueueProvider), isEmpty);
  });

  test('failed item can be retried by the user and then syncs', () async {
    await ready();
    backend.mode = 'business';
    await queue().enqueue(type: 'pos_order', payload: posPayload('retry-me'));
    await queue().flush();
    final id = container.read(offlineQueueProvider).single.id;

    backend.mode = 'ok';
    await queue().retry(id);
    expect(container.read(offlineQueueProvider), isEmpty);
    expect(backend.requests.last['uuid'], 'retry-me');
  });

  test('discard removes only on explicit request', () async {
    await ready();
    final item = await queue().enqueue(type: 'pos_order', payload: posPayload('d'));
    await queue().discard(item!.id);
    expect(container.read(offlineQueueProvider), isEmpty);
  });

  test('attendance replay sends the recorded device timestamp', () async {
    await ready();
    await queue().enqueue(type: 'hr_attendance', payload: {
      'check_in': true,
      'timestamp': '2026-10-18 03:15:00',
    });
    await queue().flush();
    expect(backend.requests.single['timestamp'], '2026-10-18 03:15:00');
    expect(backend.requests.single.containsKey('latitude'), isFalse);
  });

  test('legacy unscoped items load as failed and are never auto-replayed', () async {
    container.dispose();
    storage = InMemoryOfflineQueueStorage(jsonEncode([
      {
        'id': 'legacy1',
        'type': 'pos_order',
        'payload': {'uuid': 'legacy', 'session_id': 42},
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'attempts': 0,
      },
    ]));
    container = build();
    await ready();
    final item = container.read(offlineQueueProvider).single;
    expect(item.scope, isNull);
    expect(item.isFailed, isTrue);
    await queue().flush();
    expect(backend.requests, isEmpty);
    expect(queue().failedForCurrentScope.single.id, 'legacy1');
  });
}
