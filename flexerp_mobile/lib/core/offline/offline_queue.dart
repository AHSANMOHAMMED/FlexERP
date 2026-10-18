import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/flexerp_mobile_api.dart';
import '../api/odoo_client.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';

/// Tenant context an offline item belongs to. Items are only replayed when
/// the signed-in server / database / user / company match exactly.
class OfflineQueueScope {
  final String serverUrl;
  final String database;
  final int uid;
  final int companyId;

  const OfflineQueueScope({
    required this.serverUrl,
    required this.database,
    required this.uid,
    required this.companyId,
  });

  factory OfflineQueueScope.fromUser(AuthUser user) => OfflineQueueScope(
        serverUrl: user.serverUrl,
        database: user.database,
        uid: user.uid,
        companyId: user.companyId,
      );

  static OfflineQueueScope? fromJson(dynamic json) {
    if (json is! Map) return null;
    final uid = parseOdooInt(json['uid']);
    final companyId = parseOdooInt(json['companyId']);
    final server = json['serverUrl']?.toString();
    if (uid == null || companyId == null || server == null || server.isEmpty) return null;
    return OfflineQueueScope(
      serverUrl: server,
      database: json['database']?.toString() ?? '',
      uid: uid,
      companyId: companyId,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'database': database,
        'uid': uid,
        'companyId': companyId,
      };

  String get key => '$serverUrl|$database|$uid|$companyId';

  @override
  bool operator ==(Object other) => other is OfflineQueueScope && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

enum OfflineQueueStatus { pending, failed }

class OfflineQueueItem {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Null only for legacy (pre-scoping) items — those are never replayed
  /// automatically; an explicit user retry adopts the current tenant.
  OfflineQueueScope? scope;
  int attempts;
  String? lastError;
  OfflineQueueStatus status;

  OfflineQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.scope,
    this.attempts = 0,
    this.lastError,
    this.status = OfflineQueueStatus.pending,
  });

  /// Idempotency key (POS orders); identical on every replay.
  String? get uuid {
    final v = payload['uuid'];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool get isFailed => status == OfflineQueueStatus.failed;

  String get label {
    switch (type) {
      case 'pos_order':
        return 'POS order';
      case 'payment_register':
        return 'Invoice payment';
      case 'hr_attendance':
        return payload['check_in'] == false ? 'Attendance check-out' : 'Attendance check-in';
      default:
        return type;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        if (lastError != null) 'lastError': lastError,
        if (scope != null) 'scope': scope!.toJson(),
        'status': status.name,
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) {
    final scope = OfflineQueueScope.fromJson(json['scope']);
    final statusName = json['status']?.toString();
    var status = OfflineQueueStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => OfflineQueueStatus.pending,
    );
    var lastError = json['lastError'] as String?;
    if (scope == null && status == OfflineQueueStatus.pending) {
      // Legacy unscoped item: tenant unknown, so never auto-replay it.
      status = OfflineQueueStatus.failed;
      lastError ??= 'Saved by an older app version without tenant info — review before retrying.';
    }
    return OfflineQueueItem(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type']?.toString() ?? 'unknown',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      scope: scope,
      attempts: parseOdooInt(json['attempts']) ?? 0,
      lastError: lastError,
      status: status,
    );
  }
}

/// Persistence backend for the queue (encrypted secure storage in the app,
/// in-memory in tests).
abstract class OfflineQueueStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureOfflineQueueStorage implements OfflineQueueStorage {
  static const _secureKey = 'flexerp_offline_queue_v2';
  static const _legacyPrefsKey = 'flexerp_offline_queue_v1';

  final FlutterSecureStorage _secure;

  SecureOfflineQueueStorage({FlutterSecureStorage? secure})
      : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  @override
  Future<String?> read() async {
    final raw = await _secure.read(key: _secureKey);
    if (raw != null && raw.isNotEmpty) return raw;
    // One-time migration from the plaintext SharedPreferences queue.
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_legacyPrefsKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _secure.write(key: _secureKey, value: legacy);
        await prefs.remove(_legacyPrefsKey);
        return legacy;
      }
    } catch (e) {
      debugPrint('FlexERP: legacy offline queue migration failed: $e');
    }
    return raw;
  }

  @override
  Future<void> write(String value) => _secure.write(key: _secureKey, value: value);
}

class InMemoryOfflineQueueStorage implements OfflineQueueStorage {
  String? value;
  InMemoryOfflineQueueStorage([this.value]);

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async => value = v;
}

final offlineQueueStorageProvider = Provider<OfflineQueueStorage>((ref) {
  return SecureOfflineQueueStorage();
});

class OfflineQueueNotifier extends Notifier<List<OfflineQueueItem>> {
  /// Replay attempts before an item moves to the visible "failed" list.
  static const maxAttempts = 5;

  bool _flushing = false;
  late Future<void> _ready;

  @override
  List<OfflineQueueItem> build() {
    _ready = Future.microtask(load);
    return const [];
  }

  /// Waits for the persisted queue to be loaded.
  Future<void> get ready => _ready;

  Future<void> load() async {
    String? raw;
    try {
      raw = await ref.read(offlineQueueStorageProvider).read();
    } catch (e) {
      debugPrint('FlexERP: offline queue read failed: $e');
      return;
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => OfflineQueueItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = [...list, ...state.where((s) => !list.any((l) => l.id == s.id))];
    } catch (e) {
      // Corrupt queue must not crash the app; keep empty and overwrite on next persist.
      debugPrint('FlexERP: offline queue corrupt, resetting: $e');
    }
  }

  Future<void> _persist() async {
    try {
      await ref.read(offlineQueueStorageProvider).write(
            jsonEncode(state.map((e) => e.toJson()).toList()),
          );
    } catch (e) {
      debugPrint('FlexERP: offline queue persist failed: $e');
    }
  }

  OfflineQueueScope? get currentScope {
    final user = ref.read(currentUserProvider);
    if (user == null || user.isDemo) return null;
    return OfflineQueueScope.fromUser(user);
  }

  /// Pending items of the signed-in tenant.
  List<OfflineQueueItem> get pendingForCurrentScope {
    final scope = currentScope;
    if (scope == null) return const [];
    return state.where((i) => !i.isFailed && i.scope == scope).toList();
  }

  /// Failed items of the signed-in tenant plus legacy unscoped ones
  /// (which need a human decision).
  List<OfflineQueueItem> get failedForCurrentScope {
    final scope = currentScope;
    if (scope == null) return const [];
    return state.where((i) => i.isFailed && (i.scope == scope || i.scope == null)).toList();
  }

  Future<OfflineQueueItem?> enqueue({
    required String type,
    required Map<String, dynamic> payload,
    OfflineQueueScope? scope,
  }) async {
    await _ready;
    final effectiveScope = scope ?? currentScope;
    if (effectiveScope == null) {
      throw OdooException('Cannot queue offline work without a signed-in live session');
    }
    // Deduplicate retries that share the same client uuid.
    final uuid = payload['uuid'];
    if (uuid is String && uuid.isNotEmpty) {
      for (final existing in state) {
        if (existing.type == type && existing.uuid == uuid) return existing;
      }
    }
    final item = OfflineQueueItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      payload: Map<String, dynamic>.from(payload),
      createdAt: DateTime.now(),
      scope: effectiveScope,
    );
    state = [...state, item];
    await _persist();
    return item;
  }

  /// Replays pending items of the current tenant only.
  ///
  /// * success → removed
  /// * network failure → attempts++, flush stops (still offline)
  /// * business error (UserError/ValidationError/AccessError…) → failed list
  /// * attempts ≥ [maxAttempts] → failed list (never silently deleted)
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    try {
      await _ready;
      final api = ref.read(flexerpApiProvider);
      final scope = currentScope;
      if (scope == null || api == null) return 0;

      var flushed = 0;
      final done = <String>{};
      for (final item in List<OfflineQueueItem>.from(state)) {
        if (item.status != OfflineQueueStatus.pending || item.scope != scope) continue;
        try {
          await _dispatch(api, item);
          done.add(item.id);
          flushed++;
        } catch (e) {
          item.attempts += 1;
          item.lastError = describeError(e);
          final network = isNetworkFailure(e);
          if (!network || item.attempts >= maxAttempts) {
            item.status = OfflineQueueStatus.failed;
          }
          debugPrint('FlexERP: offline replay of ${item.type} failed '
              '(attempt ${item.attempts}, network=$network): $e');
          if (network) break; // still offline — don't hammer the rest
        }
      }
      state = [
        for (final i in state)
          if (!done.contains(i.id)) i,
      ];
      await _persist();
      return flushed;
    } finally {
      _flushing = false;
    }
  }

  /// Moves a failed item back to pending (keeping its uuid) and replays.
  Future<void> retry(String id) async {
    for (final item in state) {
      if (item.id == id) {
        item.scope ??= currentScope;
        item.status = OfflineQueueStatus.pending;
        item.attempts = 0;
      }
    }
    state = [...state];
    await _persist();
    await flush();
  }

  /// Permanently drops an item — only on explicit user request.
  Future<void> discard(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _persist();
  }

  Future<void> _dispatch(FlexerpMobileApi api, OfflineQueueItem item) async {
    switch (item.type) {
      case 'pos_order':
        // Same payload (incl. uuid) every time → server dedups.
        await api.posPushOrder(item.payload);
        break;
      case 'payment_register':
        final moveId = parseOdooInt(item.payload['move_id']);
        if (moveId == null) throw OdooException('Queued payment has no invoice id');
        await api.registerPayment(
          moveId: moveId,
          amount: (item.payload['amount'] as num?)?.toDouble(),
          journalId: parseOdooInt(item.payload['journal_id']),
          paymentDate: item.payload['payment_date'] as String?,
          memo: item.payload['memo'] as String?,
          uuid: item.uuid,
        );
        break;
      case 'hr_attendance':
        await api.hrAttendance(
          checkIn: item.payload['check_in'] as bool? ?? true,
          latitude: (item.payload['latitude'] as num?)?.toDouble(),
          longitude: (item.payload['longitude'] as num?)?.toDouble(),
          timestamp: item.payload['timestamp'] as String?,
        );
        break;
      default:
        throw OdooException('Unknown offline queue type: ${item.type}');
    }
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, List<OfflineQueueItem>>(OfflineQueueNotifier.new);
