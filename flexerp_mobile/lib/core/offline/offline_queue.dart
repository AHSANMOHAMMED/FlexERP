import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/flexerp_mobile_api.dart';
import '../api/odoo_client.dart';
import '../../data/repositories/auth_repository.dart';

class OfflineQueueItem {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int attempts;

  OfflineQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) {
    return OfflineQueueItem(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      attempts: json['attempts'] as int? ?? 0,
    );
  }
}

class OfflineQueueNotifier extends Notifier<List<OfflineQueueItem>> {
  static const _prefsKey = 'flexerp_offline_queue_v1';

  @override
  List<OfflineQueueItem> build() {
    Future.microtask(load);
    return const [];
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => OfflineQueueItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final item = OfflineQueueItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
    state = [...state, item];
    await _persist();
  }

  Future<int> flush() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return 0;

    final remaining = <OfflineQueueItem>[];
    var flushed = 0;
    for (final item in state) {
      try {
        await _dispatch(api, item);
        flushed++;
      } catch (e) {
        item.attempts += 1;
        if (item.attempts < 5) {
          remaining.add(item);
        }
        if (e is OdooException) {
          // keep for retry
        }
      }
    }
    state = remaining;
    await _persist();
    return flushed;
  }

  Future<void> _dispatch(FlexerpMobileApi api, OfflineQueueItem item) async {
    switch (item.type) {
      case 'pos_order':
        await api.posPushOrder(item.payload);
        break;
      case 'payment_register':
        await api.registerPayment(
          moveId: item.payload['move_id'] as int,
          amount: (item.payload['amount'] as num?)?.toDouble(),
          memo: item.payload['memo'] as String?,
        );
        break;
      case 'hr_attendance':
        await api.hrAttendance(
          checkIn: item.payload['check_in'] as bool? ?? true,
          latitude: (item.payload['latitude'] as num?)?.toDouble(),
          longitude: (item.payload['longitude'] as num?)?.toDouble(),
        );
        break;
      default:
        throw OdooException('Unknown offline queue type: ${item.type}');
    }
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, List<OfflineQueueItem>>(OfflineQueueNotifier.new);
