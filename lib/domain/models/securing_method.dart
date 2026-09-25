/// Result of checking which of the handbook's six approved tracked-vehicle
/// securing methods (Annex 14 §4, `rules.json`'s `sixApprovedTrackedMethods`)
/// this vehicle's own data can resolve, for the vehicles the handbook does
/// NOT already assign one mandatory method to by name (iron spur/chock-boot
/// vehicles are resolved deterministically elsewhere and never reach this
/// type). The six methods are mutually exclusive alternatives — a vehicle
/// is secured by exactly one of them, never several at once.
sealed class SecuringMethodResolution {
  const SecuringMethodResolution();
}

/// More than one approved method's data resolves for this vehicle. The
/// user must choose one of [methodNumbers] — none is auto-applied, and
/// picking one never silently adds the others' hardware.
///
/// [eligibilityConfirmed] is false when the vehicle's combat weight is
/// missing from the extract. The handbook still offers these methods for a
/// tracked vehicle — which is why the trainee is shown them and may work
/// through one — but the weight-dependent limits behind them (Table 8's
/// 7-42 t coverage for the KGUUB chocks, Table 3's stop-block sizing) cannot
/// be checked against a weight that is not recorded. Every screen that shows
/// an unconfirmed set must say so; nothing may present it as a verified
/// eligibility.
class AlternativeSecuringMethods extends SecuringMethodResolution {
  final List<int> methodNumbers;
  final bool eligibilityConfirmed;

  const AlternativeSecuringMethods(
    this.methodNumbers, {
    this.eligibilityConfirmed = true,
  });
}

/// Not enough data (combat weight) to resolve any method for this vehicle.
class UnknownSecuringMethod extends SecuringMethodResolution {
  const UnknownSecuringMethod();
}
