enum CheckStatus { pass, fail, unknown }

/// A single validation check performed by the engineering analysis engine
/// (e.g. "axle load OK?"), with the handbook citation for why it matters.
class ValidationCheck {
  final String ruleId;
  final String label;
  final CheckStatus status;
  final String detail;
  final String referenceId;

  const ValidationCheck({
    required this.ruleId,
    required this.label,
    required this.status,
    required this.detail,
    required this.referenceId,
  });
}

/// The full engineering analysis report for a vehicle placed on a platform.
class SimulationResult {
  final String vehicleId;
  final String platformId;
  final List<ValidationCheck> checks;
  final List<String> requiredHardwareIds;
  final List<String> appliedPrincipleIds;

  const SimulationResult({
    required this.vehicleId,
    required this.platformId,
    required this.checks,
    required this.requiredHardwareIds,
    required this.appliedPrincipleIds,
  });

  bool get overallPass =>
      checks.isNotEmpty && checks.every((c) => c.status != CheckStatus.fail);

  int get passCount => checks.where((c) => c.status == CheckStatus.pass).length;
  int get failCount => checks.where((c) => c.status == CheckStatus.fail).length;
  int get unknownCount => checks.where((c) => c.status == CheckStatus.unknown).length;
}
