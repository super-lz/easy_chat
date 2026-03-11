import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../common/app_constants.dart';
import '../models/connection_cache.dart';

class ConnectionPersistence {
  Future<ConnectionCache?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.connectionCacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return ConnectionCache.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(ConnectionCache cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.connectionCacheKey,
      jsonEncode(cache.toJson()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.connectionCacheKey);
  }
}
