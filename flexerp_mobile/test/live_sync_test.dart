import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexerp_mobile/core/live/live_sync.dart';

void main() {
  group('computeLiveCursor', () {
    test('since_id 0: adopt server last_id, process no events', () {
      final r = computeLiveCursor(0, {'events': <dynamic>[], 'last_id': 812});
      expect(r.nextId, 812);
      expect(r.events, isEmpty);
    });

    test('since_id 0 ignores any events a legacy server returns (no history replay)', () {
      final r = computeLiveCursor(0, {
        'events': [
          {'id': 1, 'type': 'sale'},
          {'id': 2, 'type': 'stock'},
        ],
        'latest_id': 2,
      });
      expect(r.nextId, 2);
      expect(r.events, isEmpty);
    });

    test('normal poll returns events and advances to latest id', () {
      final r = computeLiveCursor(100, {
        'events': [
          {'id': 101, 'type': 'sale'},
          {'id': 103, 'type': 'invoice'},
        ],
        'last_id': 103,
      });
      expect(r.nextId, 103);
      expect(r.events.map((e) => e['type']), ['sale', 'invoice']);
    });

    test('cursor never moves backwards', () {
      final r = computeLiveCursor(500, {'events': <dynamic>[], 'latest_id': 10});
      expect(r.nextId, 500);
    });
  });

  group('LiveSyncNotifier.start', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('starts from bootstrap live_last_event_id, not 0', () {
      container.read(liveSyncProvider.notifier).start(fromEventId: 4321, reset: true);
      final s = container.read(liveSyncProvider);
      expect(s.running, isTrue);
      expect(s.latestId, 4321);
    });

    test('without a bootstrap cursor a reset start uses since_id 0 (cursor-only poll)', () {
      container.read(liveSyncProvider.notifier).start(reset: true);
      expect(container.read(liveSyncProvider).latestId, 0);
    });
  });
}
