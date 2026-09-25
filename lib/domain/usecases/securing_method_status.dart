import '../../core/localization/app_strings.dart';
import '../../data/models/vehicle.dart';
import '../models/securing_method.dart';
import 'securing_method_resolution.dart';

/// A short, card-friendly summary of what securing-method information the
/// handbook extract gives for this vehicle — reusing the exact same
/// resolution `EngineeringValidator`/`SecuringMethodSelector` use, never a
/// separate or invented classification. This is a preview only: the
/// authoritative PASS/FAIL/UNKNOWN verdict is still produced by
/// `EngineeringValidator` once the vehicle is actually configured.
String securingMethodStatusLabel(Vehicle vehicle) {
  // Naming the type is the point: nine of the catalogue's entries are
  // design-bureau object indices with no dimensions whatsoever, and their one
  // firm fact is the spur the handbook assigns them.
  final spur = vehicle.ironSpurType;
  if (spur != null) {
    return spur.trim().isEmpty
        ? AppStrings.securingStatusIronSpur
        : AppStrings.securingStatusIronSpurTyped(spur);
  }
  final boot = vehicle.ironChockBootType;
  if (boot != null) {
    return boot.trim().isEmpty
        ? AppStrings.securingStatusIronChockBoot
        : AppStrings.securingStatusIronChockBootTyped(boot);
  }

  if (vehicle.category == VehicleCategory.tracked) {
    final resolution = resolveSecuringMethodOptions(vehicle);
    if (resolution is AlternativeSecuringMethods) {
      // A vehicle with no recorded weight still has the handbook's
      // alternatives, but the card must not let that read as a checked
      // eligibility — it gets its own, longer label.
      return resolution.eligibilityConfirmed
          ? AppStrings.securingStatusAlternatives
          : AppStrings.securingStatusAlternativesUnconfirmed;
    }
  } else if (vehicle.category == VehicleCategory.wheeled && vehicle.bracketWeightT.isAvailable) {
    if (vehicle.bracketWeightT.asDouble! <= 40.0) {
      return AppStrings.securingStatusWireLashing;
    }
  }
  return AppStrings.securingStatusUnknown;
}
