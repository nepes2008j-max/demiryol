import '../../core/localization/app_strings.dart';
import '../../data/models/platform.dart';
import '../../data/models/simulation_result.dart';
import '../../data/models/vehicle.dart';
import '../../data/repositories/handbook_repository.dart';
import '../models/chock_arrangement.dart';
import '../models/securing_method.dart';
import 'chock_arrangement_catalog.dart';
import 'securing_method_resolution.dart';
import 'wire_lashing_rule.dart';

/// Runs the handbook's engineering rules (rules.json) against a chosen
/// vehicle + platform pairing and produces a [SimulationResult].
///
/// Design rule this class enforces: if a required input value is not yet
/// transcribed from the handbook, the corresponding check reports
/// [CheckStatus.unknown] with an explanation — it never silently passes,
/// never silently fails, and never assumes a number.
class EngineeringValidator {
  final HandbookRepository repository;

  EngineeringValidator(this.repository);

  /// [appliedSecuringMethod] is the user's chosen method number (1-6) when
  /// the vehicle has more than one approved alternative available (see
  /// `securing_method_resolution.dart`) — presentation-layer state, exactly
  /// like the equipment-type selections. Leaving it null when alternatives
  /// exist never auto-applies one; it reports
  /// [AppStrings.securingMethodNotSelectedDetail] instead of guessing.
  /// [chosenChockArrangement] is the layout case the trainee picked for this
  /// placement (see `chock_arrangement_catalog.dart`), and
  /// [placementSpansCoupling] is whether the vehicle stands across the
  /// coupling of two wagons — a fact `PlacedVehicle` carries, never inferred
  /// from a drag coordinate. Both are needed to say whether the chosen
  /// arrangement is the one the plates draw for this vehicle.
  ///
  Future<SimulationResult> evaluate({
    required Vehicle vehicle,
    required Platform platform,
    int? appliedSecuringMethod,
    ChockArrangement? chosenChockArrangement,
    bool placementSpansCoupling = false,
  }) async {
    final checks = <ValidationCheck>[];
    final requiredHardware = <String>[];
    final appliedPrinciples = <String>[];

    _resolveHardware(vehicle, checks, requiredHardware, appliedPrinciples,
        appliedSecuringMethod, await repository.getRules());
    checks.add(checkChockArrangement(
      vehicle: vehicle,
      chosen: chosenChockArrangement,
      spansCoupling: placementSpansCoupling,
    ));

    return SimulationResult(
      vehicleId: vehicle.id,
      platformId: platform.id,
      checks: checks,
      requiredHardwareIds: requiredHardware,
      appliedPrincipleIds: appliedPrinciples,
    );
  }

  void _resolveHardware(
    Vehicle vehicle,
    List<ValidationCheck> checks,
    List<String> requiredHardware,
    List<String> appliedPrinciples,
    int? appliedSecuringMethod,
    Map<String, dynamic> rules,
  ) {
    if (vehicle.ironSpurType != null) {
      requiredHardware.add('att-iron-spur');
      appliedPrinciples.add('principle-vehicle-specific-hardware');
      checks.add(ValidationCheck(
        ruleId: 'rule-vehicle-specific-hardware-lookup',
        label: AppStrings.vehicleSpecificHardwareLabel,
        status: CheckStatus.pass,
        detail: AppStrings.ironSpurResolvedDetail(
            vehicle.handbookDesignation, vehicle.ironSpurType!),
        referenceId: 'para-31',
      ));
    } else if (vehicle.ironChockBootType != null) {
      requiredHardware.add('att-iron-chock-boot');
      appliedPrinciples.add('principle-vehicle-specific-hardware');
      checks.add(ValidationCheck(
        ruleId: 'rule-vehicle-specific-hardware-lookup',
        label: AppStrings.vehicleSpecificHardwareLabel,
        status: CheckStatus.pass,
        detail: AppStrings.ironChockBootResolvedDetail(
            vehicle.handbookDesignation, vehicle.ironChockBootType!),
        referenceId: 'para-32',
      ));
    } else if (vehicle.category == VehicleCategory.tracked) {
      _resolveAlternativeTrackedMethod(
          vehicle, appliedSecuringMethod, checks, requiredHardware, appliedPrinciples);
    } else if (vehicle.category == VehicleCategory.wheeled) {
      // Chocks first, and unconditionally: the plate states that every
      // wheeled vehicle is secured with quadrilateral wood chocks whatever
      // it weighs (only how many depends on the bracket). This branch used
      // to require a combat weight before resolving anything at all, so a
      // lorry with no recorded weight — which is every lorry in the
      // catalogue — came out of the validator with no required hardware and
      // no check saying why.
      requiredHardware.add('att-wood-chock');
      checks.add(const ValidationCheck(
        ruleId: 'rule-wheeled-chock-count',
        label: AppStrings.wheeledChockRequiredLabel,
        status: CheckStatus.pass,
        detail: AppStrings.wheeledChockRequiredDetail,
        referenceId: 'plate-06',
      ));

      if (!vehicle.bracketWeightT.isAvailable) {
        checks.add(const ValidationCheck(
          ruleId: 'rule-wheeled-lashing-count',
          label: AppStrings.wireLashingCountResolvedLabel,
          status: CheckStatus.unknown,
          detail: AppStrings.wireLashingCountUnknownDetail,
          referenceId: 'para-55',
        ));
        return;
      }

      final w = vehicle.bracketWeightT.asDouble!;
      appliedPrinciples.add('principle-weight-class-method-count');
      // Read from `rule-wheeled-lashing-count` rather than repeating its
      // brackets here: the schematic already reads them through
      // `requiredWireLashingCount`, and two copies of one rule drift.
      final lashings = requiredWireLashingCount(w, rules);
      if (lashings != null) {
        requiredHardware.add('att-wire-lashing');
        checks.add(ValidationCheck(
          ruleId: 'rule-wheeled-lashing-count',
          label: AppStrings.wireLashingCountResolvedLabel,
          status: CheckStatus.pass,
          detail: AppStrings.wireLashingCountDetail(lashings, w.toStringAsFixed(1)),
          referenceId: 'para-55',
        ));
      } else {
        checks.add(const ValidationCheck(
          ruleId: 'rule-wheeled-lashing-count',
          label: AppStrings.wireLashingCountResolvedLabel,
          status: CheckStatus.unknown,
          detail: AppStrings.wireLashingCountUnknownDetail,
          referenceId: 'para-55',
        ));
      }
    } else {
      checks.add(const ValidationCheck(
        ruleId: 'rule-hardware-resolution',
        label: AppStrings.hardwareResolutionFallbackLabel,
        status: CheckStatus.unknown,
        detail: AppStrings.hardwareResolutionFallbackDetail,
        referenceId: 'para-34',
      ));
    }
  }

  /// For tracked vehicles the handbook does NOT already assign one
  /// mandatory vehicle-specific method to (iron spur/chock-boot vehicles
  /// are handled above, deterministically): resolves which of the
  /// approved alternative methods (Annex 14 §4) this vehicle's data
  /// supports, and — only once the user has actually applied one — adds
  /// that ONE method's hardware. It never adds more than one method's
  /// hardware at a time, and never silently picks one on the user's
  /// behalf.
  void _resolveAlternativeTrackedMethod(
    Vehicle vehicle,
    int? appliedMethod,
    List<ValidationCheck> checks,
    List<String> requiredHardware,
    List<String> appliedPrinciples,
  ) {
    final resolution = resolveSecuringMethodOptions(vehicle);
    if (resolution is UnknownSecuringMethod) {
      checks.add(const ValidationCheck(
        ruleId: 'rule-securing-method-alternatives',
        label: AppStrings.securingMethodCheckLabel,
        status: CheckStatus.unknown,
        detail: AppStrings.securingMethodUnknownDetail,
        referenceId: 'para-34',
      ));
      return;
    }

    final alternatives = resolution as AlternativeSecuringMethods;
    final options = alternatives.methodNumbers;
    appliedPrinciples.add('principle-weight-class-method-count');

    if (appliedMethod == null) {
      checks.add(ValidationCheck(
        ruleId: 'rule-securing-method-alternatives',
        label: AppStrings.securingMethodCheckLabel,
        status: CheckStatus.unknown,
        detail: AppStrings.securingMethodNotSelectedDetail(options),
        referenceId: 'para-34',
      ));
      return;
    }

    if (!options.contains(appliedMethod)) {
      checks.add(ValidationCheck(
        ruleId: 'rule-securing-method-alternatives',
        label: AppStrings.securingMethodCheckLabel,
        status: CheckStatus.fail,
        detail: AppStrings.securingMethodInvalidDetail(appliedMethod, options),
        referenceId: methodReferenceId(appliedMethod),
      ));
      return;
    }

    requiredHardware.addAll(hardwareIdsForSecuringMethod(appliedMethod, vehicle));
    // Applying a method the handbook offers is not the same as having
    // confirmed the vehicle qualifies for it. With no combat weight recorded,
    // the KGUUB bracket and the stop-block sizing behind these methods cannot
    // be checked, so the result stays UNKNOWN and says which number is
    // missing — it is never upgraded to a pass by the act of choosing.
    final confirmed = alternatives.eligibilityConfirmed;
    checks.add(ValidationCheck(
      ruleId: 'rule-securing-method-alternatives',
      label: AppStrings.securingMethodCheckLabel,
      status: confirmed ? CheckStatus.pass : CheckStatus.unknown,
      detail: confirmed
          ? AppStrings.securingMethodAppliedDetail(appliedMethod)
          : AppStrings.securingMethodAppliedUnconfirmedDetail(appliedMethod),
      referenceId: methodReferenceId(appliedMethod),
    ));
  }
}
