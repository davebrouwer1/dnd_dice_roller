// lib/models/preset_roll.dart
import 'package:flutter/foundation.dart';

class PresetRoll {
  final String id;
  String name;
  final int numberOfDice;
  final int sides;
  final String baseDiceType;
  final int modifier;
  final bool isAdvantage;
  final bool isDisadvantage;

  PresetRoll({
    required this.id,
    required this.name,
    required this.numberOfDice,
    required this.sides,
    required this.baseDiceType,
    required this.modifier,
    this.isAdvantage = false,
    this.isDisadvantage = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'numberOfDice': numberOfDice,
    'sides': sides,
    'baseDiceType': baseDiceType,
    'modifier': modifier,
    'isAdvantage': isAdvantage,
    'isDisadvantage': isDisadvantage,
  };

  factory PresetRoll.fromJson(Map<String, dynamic> json) => PresetRoll(
    id: json['id'] as String,
    name: json['name'] as String,
    numberOfDice: json['numberOfDice'] as int,
    sides: json['sides'] as int,
    baseDiceType: json['baseDiceType'] as String,
    modifier: json['modifier'] as int,
    isAdvantage: json['isAdvantage'] as bool? ?? false,
    isDisadvantage: json['isDisadvantage'] as bool? ?? false,
  );

  @override
  String toString() {
    String advDis = '';
    if (isAdvantage) advDis = ' (Adv)';
    if (isDisadvantage) advDis = ' (Dis)';
    String modStr =
        modifier == 0 ? '' : (modifier > 0 ? ' +$modifier' : ' $modifier');
    return '$name: $numberOfDice$baseDiceType$modStr$advDis';
  }
}
