// lib/services/persistence_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/preset_roll.dart'; // Import the model

// Define the keys as constants so they can be reused without typos
const String kAdsRemovedPrefsKey = 'ads_removed_status';
const String kPresetsPrefsKey = 'dice_presets_list';

class PersistenceService {
  // A private constructor to prevent instantiation
  PersistenceService._();

  // --- Ads Status Persistence ---

  static Future<bool> loadAdsRemovedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kAdsRemovedPrefsKey) ?? false;
  }

  static Future<void> saveAdsRemovedStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAdsRemovedPrefsKey, value);
  }

  // --- Presets Persistence ---

  static Future<List<PresetRoll>> loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? presetsJson = prefs.getStringList(kPresetsPrefsKey);

    if (presetsJson == null) {
      return []; // Return an empty list if no data is found
    }

    try {
      return presetsJson
          .map(
            (jsonString) => PresetRoll.fromJson(
              jsonDecode(jsonString) as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint("Error decoding presets: $e. Clearing corrupted presets.");
      // If data is corrupted, clear it to prevent future errors
      await prefs.remove(kPresetsPrefsKey);
      return [];
    }
  }

  static Future<void> savePresets(List<PresetRoll> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> presetsJson =
        presets.map((preset) => jsonEncode(preset.toJson())).toList();
    await prefs.setStringList(kPresetsPrefsKey, presetsJson);
  }
}
