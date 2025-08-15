// lib/models/roll_entry.dart

class RollEntry {
  final String description;
  final int totalResult;
  final List<int> individualRolls;
  final int modifierValue;
  final bool wasAdvantage;
  final bool wasDisadvantage;
  final List<int>? advDisRawRolls;

  RollEntry({
    required this.description,
    required this.totalResult,
    required this.individualRolls,
    required this.modifierValue,
    this.wasAdvantage = false,
    this.wasDisadvantage = false,
    this.advDisRawRolls,
  });

  int? get _dieSides {
    if (individualRolls.length != 1) return null;
    final match = RegExp(r"1d(\d+|%)").firstMatch(description);
    if (match != null) {
      String sideStr = match.group(1)!;
      if (sideStr == '%') return 100;
      return int.tryParse(sideStr);
    }
    return null;
  }

  bool get isCriticalSuccess {
    if (individualRolls.length == 1) {
      final sides = _dieSides;
      return sides != null && individualRolls.first == sides;
    }
    return false;
  }

  bool get isCriticalFumble {
    if (individualRolls.length == 1) {
      final sides = _dieSides;
      return sides != null && individualRolls.first == 1;
    }
    return false;
  }

  @override
  String toString() {
    String rollsStr = individualRolls.join(', ');
    String modStr =
        modifierValue == 0
            ? ""
            : (modifierValue > 0 ? "+$modifierValue" : "$modifierValue");
    String advDisStr = "";
    if (wasAdvantage) advDisStr = " (Adv)";
    if (wasDisadvantage) advDisStr = " (Dis)";
    String extraRollsDisplay = "";
    if (advDisRawRolls != null && advDisRawRolls!.length == 2) {
      extraRollsDisplay = " [${advDisRawRolls!.join(', ')}]";
    }
    return "$description$advDisStr (Roll: $rollsStr$extraRollsDisplay) $modStr = $totalResult";
  }
}
