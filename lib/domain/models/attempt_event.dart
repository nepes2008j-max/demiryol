/// Something the trainee did that the handbook says is wrong, recorded as it
/// happened.
///
/// Most mistakes are already visible in the checks a configuration produces —
/// a FAIL check *is* a mistake, with its citation attached. This type is for
/// the ones the checks cannot see because they never became part of a
/// configuration: choosing a wagon that cannot be loaded, for instance, is
/// rejected at the tap and never reaches the validator, so without a log it
/// would leave no trace in the result at all.
enum AttemptEventKind {
  /// A wagon type that may not carry the load was chosen.
  wrongWagonType,

  /// A hardware type was applied that is not the one the handbook mandates.
  equipmentMismatch,

  /// A securing method was applied that this vehicle's data does not support.
  invalidSecuringMethod,

  /// More was loaded onto a wagon than its deck can take.
  wagonOverloaded,
}

class AttemptEvent {
  final AttemptEventKind kind;

  /// What happened, in the interface's language, ready to show.
  final String description;

  /// The handbook citation for why it is wrong, so a mistake can be read back
  /// to its source exactly like a check can.
  final String referenceId;

  final DateTime at;

  const AttemptEvent({
    required this.kind,
    required this.description,
    required this.referenceId,
    required this.at,
  });

  @override
  bool operator ==(Object other) =>
      other is AttemptEvent &&
      other.kind == kind &&
      other.description == description &&
      other.referenceId == referenceId &&
      other.at == at;

  @override
  int get hashCode => Object.hash(kind, description, referenceId, at);
}
