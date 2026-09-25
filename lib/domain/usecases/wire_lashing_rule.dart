/// Number of wire lashings required for method 2 (para. 55), read directly
/// from `rules.json`'s own weight-bracket lookup table
/// (`rule-wheeled-lashing-count`) — never a hardcoded duplicate of that
/// rule, so the schematic always draws exactly as many connections as the
/// extracted rule actually specifies. Returns null when the vehicle's
/// weight falls outside every bracket the extract defines, or the rule
/// itself isn't found.
int? requiredWireLashingCount(double weightT, Map<String, dynamic> rules) {
  final ruleList = (rules['rules'] as List?) ?? const [];
  Map<String, dynamic>? rule;
  for (final entry in ruleList) {
    final m = entry as Map<String, dynamic>;
    if (m['id'] == 'rule-wheeled-lashing-count') {
      rule = m;
      break;
    }
  }
  final lookup = (rule?['lookup'] as List?) ?? const [];
  for (final entry in lookup) {
    final e = entry as Map<String, dynamic>;
    final maxT = (e['combatWeightMaxT'] as num).toDouble();
    if (weightT <= maxT) return e['lashingsRequired'] as int;
  }
  return null;
}
