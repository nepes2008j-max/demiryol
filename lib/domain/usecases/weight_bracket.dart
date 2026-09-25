/// Parses a bracket string exactly as it appears in `measurements.json` and
/// `rules.json`, where the source keeps ranges as free text rather than as a
/// structured min/max.
///
/// Six forms occur across the tables, and all six are handled:
///
/// * `"up to 12.0"` — Table 3's first row
/// * `"over 18.0"` — Table 3's last row
/// * `"12.1-18.0"` / `"7-25"` — the closed brackets
/// * `"under 500"` — Table 2's first row (chock size by wheel diameter)
/// * `"1600 and above"` — Table 2's last row
/// * `"<=45"` — Table 7's first angle band, and its `>=`, `<`, `>` siblings
///
/// Anything else returns false rather than guessing — and that silence is
/// exactly the risk: while this only ever read the tracked weight table, the
/// `"under 500"` / `"1600 and above"` forms of Table 2 matched nothing (so a
/// wheeled vehicle's chock size resolved to none) and the `"<=45"` form of
/// Table 7 matched nothing (so no lashing strand count could ever be looked
/// up). A new table's wording belongs here before it is read anywhere.
bool valueMatchesRange(double value, String range) {
  final lower = range.trim().toLowerCase();

  // Comparison operators, as Table 7 writes its angle bands. Checked before
  // the word forms because the operator carries the whole meaning.
  for (final entry in const [('<=', 0), ('>=', 1), ('<', 2), ('>', 3)]) {
    final symbol = entry.$1;
    if (!lower.startsWith(symbol)) continue;
    final bound = double.tryParse(lower.substring(symbol.length).trim());
    if (bound == null) return false;
    return switch (entry.$2) {
      0 => value <= bound,
      1 => value >= bound,
      2 => value < bound,
      _ => value > bound,
    };
  }

  if (lower.startsWith('up to ')) {
    final max = double.tryParse(lower.substring('up to '.length).trim());
    return max != null && value <= max;
  }
  if (lower.startsWith('under ')) {
    final max = double.tryParse(lower.substring('under '.length).trim());
    return max != null && value < max;
  }
  if (lower.startsWith('over ')) {
    final min = double.tryParse(lower.substring('over '.length).trim());
    return min != null && value > min;
  }
  if (lower.endsWith(' and above')) {
    final min = double.tryParse(
        lower.substring(0, lower.length - ' and above'.length).trim());
    return min != null && value >= min;
  }

  final parts = lower.split('-');
  if (parts.length == 2) {
    final min = double.tryParse(parts[0].trim());
    final max = double.tryParse(parts[1].trim());
    return min != null && max != null && value >= min && value <= max;
  }
  return false;
}

/// [valueMatchesRange] under the name the weight-bracket callers read better
/// with. Same function: the brackets are the same free text whether they
/// count tonnes or millimetres.
bool weightMatchesRange(double weightT, String range) =>
    valueMatchesRange(weightT, range);
