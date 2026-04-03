import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/history_item.dart';

class LocalStorageService {
  const LocalStorageService();

  static const String _settingsKey = 'summary_app_settings_v1';
  static const String _historyKey = 'summary_app_history_v1';

  Future<AppSettings> loadSettings() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      final AppSettings defaults = AppSettings.defaults(
        deviceId: createDeviceId(),
      );
      await saveSettings(defaults);
      return defaults;
    }

    try {
      final AppSettings settings = AppSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (settings.deviceId.isNotEmpty) {
        return settings;
      }

      final AppSettings updated = settings.copyWith(
        deviceId: createDeviceId(),
        remainingFreeUses: AppSettings.defaults().remainingFreeUses,
      );
      await saveSettings(updated);
      return updated;
    } catch (_) {
      final AppSettings defaults = AppSettings.defaults(
        deviceId: createDeviceId(),
      );
      await saveSettings(defaults);
      return defaults;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<HistoryItem>> loadHistory() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> rawHistory =
        preferences.getStringList(_historyKey) ?? <String>[];

    return rawHistory
        .map((String item) {
          try {
            return HistoryItem.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            );
          } catch (_) {
            return HistoryItem(
              source: 'Corrupted item',
              language: 'Unknown',
              summary: '',
              bulletPoints: <String>[],
              transcriptPreview: '',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              serviceLabel: 'Unknown',
            );
          }
        })
        .where((HistoryItem item) => item.summary.isNotEmpty)
        .toList();
  }

  Future<void> saveHistory(List<HistoryItem> history) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> encoded = history
        .map((HistoryItem item) => jsonEncode(item.toJson()))
        .toList();
    await preferences.setStringList(_historyKey, encoded);
  }

  String createDeviceId() {
    final Random random = Random();
    final String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    final String suffix =
        '${random.nextInt(1 << 30).toRadixString(16)}${random.nextInt(1 << 30).toRadixString(16)}';
    return 'device_$timestamp$suffix';
  }
}
