import '../../data/models/vehicle.dart';
import '../models/securing_method.dart';

/// Determines which of the handbook's six approved tracked-vehicle securing
/// methods (Annex 14 §4) this vehicle's OWN data can resolve, for the
/// vehicles the handbook does not already name one mandatory method for
/// (iron spur/chock-boot vehicles are resolved deterministically elsewhere
/// — via `vehicle.ironSpurType`/`ironChockBootType` — and never reach this
/// function).
///
/// Method 1 (KGUUB) needs the vehicle's combat weight to fall within
/// Table 8's 7-42t coverage; with no weight recorded it is still offered,
/// with eligibility marked unconfirmed rather than assumed either way. Methods 3 and 5 both rest on the wood
/// stop-block sizing in Table 3, which covers every weight once it is
/// known, so both are always offered alongside method 1 (never
/// auto-preferring one). Methods 2, 4, and 6 are excluded here: 2 and 4 are
/// vehicle-specific (handled elsewhere), and 6 is restricted to named
/// object numbers ('object 765'/'675') that do not appear anywhere in the
/// extracted vehicle data, so no vehicle in this dataset can ever be
/// confirmed eligible for it.
SecuringMethodResolution resolveSecuringMethodOptions(Vehicle vehicle) {
  if (vehicle.category != VehicleCategory.tracked) return const UnknownSecuringMethod();

  final weight = vehicle.bracketWeightT.asDouble;
  if (weight == null) {
    // The handbook gives a tracked vehicle these three alternatives; what a
    // missing weight prevents is confirming the KGUUB bracket and sizing the
    // stop-blocks, not knowing that the methods exist. Refusing to show them
    // taught the trainee nothing at all — no vehicle in the current extract
    // records a combat weight, so the choice the plates are built around was
    // never once offered. They are offered here with eligibility explicitly
    // unconfirmed, and every check downstream keeps saying so.
    return const AlternativeSecuringMethods([1, 3, 5], eligibilityConfirmed: false);
  }

  final methods = <int>[
    if (weight >= 7.0 && weight <= 42.0) 1,
    3,
    5,
  ];
  return AlternativeSecuringMethods(methods);
}

/// The hardware ids used together (cumulative) within one approved
/// securing method — straight from that method's own handbook name in
/// `sixApprovedTrackedMethods` (e.g. method 3, "Wood stop-blocks + wire
/// lashings") and the matching entries in `attachments.json`. Method 1's
/// concrete KGUUB variant still depends on the vehicle's own weight
/// bracket (Table 8).
List<String> hardwareIdsForSecuringMethod(int methodNumber, Vehicle vehicle) {
  switch (methodNumber) {
    case 1:
      final w = vehicle.bracketWeightT.asDouble;
      if (w == null) return const [];
      if (w >= 7.0 && w <= 25.0) return const ['att-kguub-1g'];
      if (w > 25.0 && w <= 42.0) return const ['att-kguub-2g'];
      return const [];
    case 2:
      return const ['att-iron-spur'];
    case 3:
      return const ['att-wood-chock', 'att-wire-lashing'];
    case 4:
      return const ['att-iron-chock-boot'];
    case 5:
      return const ['att-wood-chock', 'att-wood-packing'];
    case 6:
      return const ['att-clamp-tensioner', 'att-clamp'];
    default:
      return const [];
  }
}

/// The handbook paragraph citing one specific approved method, straight
/// from `sixApprovedTrackedMethods`' own `referenceId` per method.
String methodReferenceId(int methodNumber) {
  const referenceIds = {
    1: 'para-35',
    2: 'para-39',
    3: 'para-40',
    4: 'para-32',
    5: 'para-34',
    6: 'para-33',
  };
  return referenceIds[methodNumber] ?? 'para-34';
}
