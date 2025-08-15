// lib/providers/dice_roller_provider.dart
import 'dart:math';
import 'package:flutter/foundation.dart';

// CORRECT: Imports the models from their new, single source of truth.
import '../models/preset_roll.dart';
import '../models/roll_entry.dart';
import '../services/persistence_service.dart';

// --- Constants for Provider Logic ---
const int kMaxDiceCount = 100;
const int kMinDiceCount = 1;
const int kMaxModifier = 100;
const int kMinModifier = -100;
const int kMaxHistoryLength = 20;

// CORRECT: The PresetRoll and RollEntry classes are NOT defined here anymore.

class DiceRollerProvider with ChangeNotifier {
  final Random _random = Random();

  // --- State Variables ---
  List<RollEntry> _history = [];
  bool _adsRemoved = false;
  List<PresetRoll> _presets = [];

  int _numberOfDice = kMinDiceCount;
  int _modifier = 0;
  bool _isAdvantage = false;
  bool _isDisadvantage = false;
  int _currentDieSidesForPreset = 20;
  String _currentBaseDiceTypeForPreset = "d20";

  bool _isRolling = false;

  // --- Getters ---
  List<RollEntry> get history => List.unmodifiable(_history);
  bool get adsRemoved => _adsRemoved;
  List<PresetRoll> get presets => List.unmodifiable(_presets);
  int get numberOfDice => _numberOfDice;
  int get modifier => _modifier;
  bool get isAdvantage => _isAdvantage;
  bool get isDisadvantage => _isDisadvantage;
  bool get isRolling => _isRolling;
  int get currentDieSides => _currentDieSidesForPreset;
  String get currentBaseDiceType => _currentBaseDiceTypeForPreset;

  // --- Constructor ---
  DiceRollerProvider() {
    _initialize();
  }

  // --- Initialization ---
  Future<void> _initialize() async {
    _adsRemoved = await PersistenceService.loadAdsRemovedStatus();
    _presets = await PersistenceService.loadPresets();
    notifyListeners();
  }

  // --- State Management Methods ---

  Future<void> setAdsRemoved(bool value) async {
    _adsRemoved = value;
    await PersistenceService.saveAdsRemovedStatus(value);
    notifyListeners();
  }

  void setNumberOfDice(int count) {
    int newCount = count.clamp(kMinDiceCount, kMaxDiceCount);
    if (_numberOfDice != newCount) {
      _numberOfDice = newCount;
      if (_numberOfDice != 1) {
        _isAdvantage = false;
        _isDisadvantage = false;
      }
      notifyListeners();
    }
  }

  void setModifier(int modValue) {
    int newModifier = modValue.clamp(kMinModifier, kMaxModifier);
    if (_modifier != newModifier) {
      _modifier = newModifier;
      notifyListeners();
    }
  }

  void resetConfiguration() {
    bool needsNotify = false;
    if (_numberOfDice != kMinDiceCount) {
      _numberOfDice = kMinDiceCount;
      needsNotify = true;
    }
    if (_modifier != 0) {
      _modifier = 0;
      needsNotify = true;
    }
    if (_isAdvantage) {
      _isAdvantage = false;
      needsNotify = true;
    }
    if (_isDisadvantage) {
      _isDisadvantage = false;
      needsNotify = true;
    }
    if (needsNotify) {
      notifyListeners();
    }
  }

  void toggleAdvantage() {
    bool originalAdvantage = _isAdvantage;
    _isAdvantage = !_isAdvantage;
    if (_isAdvantage) {
      _isDisadvantage = false;
      if (_numberOfDice != 1) {
        _numberOfDice = 1;
      }
    }
    if (originalAdvantage != _isAdvantage ||
        (_isAdvantage && _numberOfDice != 1)) {
      notifyListeners();
    } else if (originalAdvantage != _isAdvantage) {
      notifyListeners();
    }
  }

  void toggleDisadvantage() {
    bool originalDisadvantage = _isDisadvantage;
    _isDisadvantage = !_isDisadvantage;
    if (_isDisadvantage) {
      _isAdvantage = false;
      if (_numberOfDice != 1) {
        _numberOfDice = 1;
      }
    }
    if (originalDisadvantage != _isDisadvantage ||
        (_isDisadvantage && _numberOfDice != 1)) {
      notifyListeners();
    } else if (originalDisadvantage != _isDisadvantage) {
      notifyListeners();
    }
  }

  Future<void> rollDice(int sides, String baseDiceType) async {
    _currentDieSidesForPreset = sides;
    _currentBaseDiceTypeForPreset = baseDiceType;

    List<int> individualRolls = [];
    int sumOfRolls = 0;
    List<int>? actualAdvDisRolls;
    bool applyAdvDis = (_isAdvantage || _isDisadvantage) && _numberOfDice == 1;
    String currentDescription;

    if (applyAdvDis) {
      int roll1 = _random.nextInt(sides) + 1;
      int roll2 = _random.nextInt(sides) + 1;
      actualAdvDisRolls = [roll1, roll2];
      sumOfRolls = _isAdvantage ? max(roll1, roll2) : min(roll1, roll2);
      individualRolls.add(sumOfRolls);
      currentDescription = "1$baseDiceType";
    } else {
      for (int i = 0; i < _numberOfDice; i++) {
        int roll = _random.nextInt(sides) + 1;
        individualRolls.add(roll);
        sumOfRolls += roll;
      }
      currentDescription = "${_numberOfDice}$baseDiceType";
    }

    int totalResult = sumOfRolls + _modifier;
    final entry = RollEntry(
      description: currentDescription,
      totalResult: totalResult,
      individualRolls: individualRolls,
      modifierValue: _modifier,
      wasAdvantage: applyAdvDis && _isAdvantage,
      wasDisadvantage: applyAdvDis && _isDisadvantage,
      advDisRawRolls: actualAdvDisRolls,
    );

    _history.insert(0, entry);
    if (_history.length > kMaxHistoryLength) {
      _history.removeLast();
    }

    _isRolling = true;
    notifyListeners();
  }

  void endRolling() {
    _isRolling = false;
    notifyListeners();
  }

  // --- Preset Management Methods ---

  Future<void> addPreset(String name) async {
    if (name.trim().isEmpty) return;

    final newPreset = PresetRoll(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      numberOfDice: _numberOfDice,
      sides: _currentDieSidesForPreset,
      baseDiceType: _currentBaseDiceTypeForPreset,
      modifier: _modifier,
      isAdvantage: _isAdvantage,
      isDisadvantage: _isDisadvantage,
    );
    _presets.add(newPreset);
    await PersistenceService.savePresets(_presets);
    notifyListeners();
  }

  Future<void> removePreset(String presetId) async {
    _presets.removeWhere((preset) => preset.id == presetId);
    await PersistenceService.savePresets(_presets);
    notifyListeners();
  }

  Future<void> updatePresetName(String presetId, String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      final preset = _presets.firstWhere((p) => p.id == presetId);
      preset.name = newName.trim();
      await PersistenceService.savePresets(_presets);
      notifyListeners();
    } catch (e) {
      debugPrint(
        "Error updating preset name: Preset with ID $presetId not found. $e",
      );
    }
  }

  void loadPresetConfiguration(PresetRoll preset) {
    _numberOfDice = preset.numberOfDice;
    _modifier = preset.modifier;
    _isAdvantage = preset.isAdvantage;
    _isDisadvantage = preset.isDisadvantage;
    _currentDieSidesForPreset = preset.sides;
    _currentBaseDiceTypeForPreset = preset.baseDiceType;

    if (_isAdvantage || _isDisadvantage) {
      _numberOfDice = 1;
    }
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
}
