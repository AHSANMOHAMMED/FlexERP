import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  final String serverUrl;
  final String database;
  final String sessionId;
  final int uid;
  final String name;
  final String email;
  final int companyId;
  final String companyName;
  final String vendorId;
  final String role;
  final List<String> groups;
  final Map<String, bool> features;
  final bool enforceHttps;

  const StoredSession({
    required this.serverUrl,
    required this.database,
    required this.sessionId,
    required this.uid,
    required this.name,
    required this.email,
    required this.companyId,
    required this.companyName,
    required this.vendorId,
    required this.role,
    required this.groups,
    required this.features,
    this.enforceHttps = true,
  });

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'database': database,
        'sessionId': sessionId,
        'uid': uid,
        'name': name,
        'email': email,
        'companyId': companyId,
        'companyName': companyName,
        'vendorId': vendorId,
        'role': role,
        'groups': groups,
        'features': features,
        'enforceHttps': enforceHttps,
      };

  factory StoredSession.fromJson(Map<String, dynamic> json) {
    return StoredSession(
      serverUrl: json['serverUrl'] as String,
      database: json['database'] as String,
      sessionId: json['sessionId'] as String,
      uid: _asInt(json['uid']) ?? (throw const FormatException('session uid missing')),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      companyId: _asInt(json['companyId']) ?? 1,
      companyName: json['companyName'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? 'VND-001',
      role: json['role'] as String? ?? 'employee',
      groups: List<String>.from(json['groups'] as List? ?? const []),
      features: Map<String, bool>.from(
        (json['features'] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)) ??
            const {},
      ),
      enforceHttps: json['enforceHttps'] as bool? ?? true,
    );
  }
}

int? _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));

class SecureSessionStore {
  static const _secureKey = 'flexerp_secure_session_v1';
  static const _prefsKey = 'flexerp_server_prefs_v1';

  final FlutterSecureStorage _secure;

  SecureSessionStore({FlutterSecureStorage? secure})
      : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveSession(StoredSession session) async {
    await _secure.write(key: _secureKey, value: jsonEncode(session.toJson()));
  }

  Future<StoredSession?> readSession() async {
    try {
      final raw = await _secure.read(key: _secureKey);
      if (raw == null || raw.isEmpty) return null;
      return StoredSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // Corrupt / partial cache or keystore failure — clear so desktop/mobile
      // never boot into a blank auth loop.
      debugPrint('FlexERP: stored session unreadable, clearing: $e');
      try {
        await clearSession();
      } catch (clearError) {
        debugPrint('FlexERP: failed to clear stored session: $clearError');
      }
      return null;
    }
  }

  Future<void> clearSession() async {
    await _secure.delete(key: _secureKey);
  }

  Future<void> saveServerPrefs({
    required String serverUrl,
    required String database,
    required bool enforceHttps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'serverUrl': serverUrl,
        'database': database,
        'enforceHttps': enforceHttps,
      }),
    );
  }

  Future<Map<String, dynamic>?> readServerPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FlexERP: server prefs corrupt: $e');
      return null;
    }
  }
}
