import '../../core/localization/app_strings.dart';

/// Rewrites a raw `"TODO: Fill from Handbook Page XX"` extraction marker
/// (optionally with a trailing `"(...)"` note) into professional,
/// user-facing Turkmen wording. The internal TODO marker in the JSON/model
/// layer is untouched by this — it is a presentation-only transform,
/// applied at the point a value is rendered to the screen.
String presentHandbookText(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.toUpperCase().startsWith('TODO')) return raw;

  final noteMatch = RegExp(r'\(([^()]*)\)\s*$').firstMatch(trimmed);
  final note = noteMatch?.group(1)?.trim();
  const base = AppStrings.notAvailableInHandbook;
  return (note == null || note.isEmpty) ? base : '$base ($note)';
}

/// Wraps a single engineering value that must come from the handbook.
///
/// This is the mechanism that enforces "never invent engineering values":
/// every dimension, weight, or count in the data model is a [HandbookField]
/// instead of a raw `double`/`int`. If the JSON source has a real number,
/// [isAvailable] is true and [numericValue] is usable in calculations. If
/// the source only has a `"TODO: Fill from Handbook Page XX"` string (or is
/// missing), [isAvailable] is false and [display] renders professional
/// "not available" wording instead of the raw internal marker — callers
/// MUST check [isAvailable] before using a value in a validation rule,
/// rather than silently defaulting to 0 or a guess.
class HandbookField {
  final dynamic _raw;

  const HandbookField(this._raw);

  factory HandbookField.fromJson(dynamic json) => HandbookField(json);

  bool get isAvailable => _raw is num;

  bool get isTodo =>
      _raw == null || (_raw is String && _raw.trim().toUpperCase().startsWith('TODO'));

  num? get numericValue => _raw is num ? _raw : null;

  double? get asDouble => numericValue?.toDouble();

  /// Human-readable value for the UI: the real number (as given), or a
  /// professional "not available" message when the handbook doesn't say.
  String display({String unit = ''}) {
    if (isAvailable) {
      final n = numericValue!;
      final numStr = n == n.roundToDouble() ? n.toInt().toString() : n.toString();
      return unit.isEmpty ? numStr : '$numStr $unit';
    }
    if (_raw is String) return presentHandbookText(_raw);
    return AppStrings.notAvailableInHandbook;
  }

  /// The value, or the three-word "not in the source" form — for cards and
  /// dense rows where the full sentence crowds out the values that are known.
  /// [display] stays the right choice on a spec sheet, where there is room to
  /// say it properly.
  String displayCompact({String unit = ''}) =>
      isAvailable ? display(unit: unit) : AppStrings.notAvailableShort;

  @override
  String toString() => display();
}
