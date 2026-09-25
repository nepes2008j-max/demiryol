import '../../core/localization/app_strings.dart';
import '../../data/models/platform.dart';
import '../../data/models/simulation_result.dart';

/// Whether the train the trainee has built still counts as a legal military
/// echelon.
///
/// The handbook's Chapter I measures a train in **conditional wagons**
/// (şertli wagon), not in physical ones: a loaded freight wagon counts as
/// 33 t net, a soft-class passenger wagon as 3 t, and so on, and an echelon
/// belongs to a class — 40 conditional wagons up to 1500 t, 57 up to 3000 t.
/// Those classes have been sitting in `platforms.json` unused since the data
/// was extracted; nothing in the app ever compared a train against one.
///
/// What can be checked with what the extract carries is the **wagon count**
/// against the class's limit. The tonnage cannot: it needs each wagon's net
/// load, and no vehicle in the extract has a weight. So the weight side
/// reports UNKNOWN and says which figure is missing, rather than adding up
/// zeroes and declaring the train legal.
class EchelonClass {
  final String id;
  final String name;
  final int conditionalWagons;
  final double maxTrainWeightT;
  final String referenceId;

  const EchelonClass({
    required this.id,
    required this.name,
    required this.conditionalWagons,
    required this.maxTrainWeightT,
    required this.referenceId,
  });
}

/// The echelon classes the data defines, smallest first.
List<EchelonClass> echelonClassesFrom(Iterable<Platform> platforms) {
  final classes = <EchelonClass>[];
  for (final platform in platforms) {
    if (platform.kind != PlatformKind.echelonClass) continue;
    final wagons = platform.conditionalWagonCount?.numericValue?.toInt();
    final weight = platform.trainMaxWeightT?.asDouble;
    if (wagons == null || weight == null) continue;
    classes.add(EchelonClass(
      id: platform.id,
      name: platform.name,
      conditionalWagons: wagons,
      maxTrainWeightT: weight,
      referenceId: platform.referenceId,
    ));
  }
  classes.sort((a, b) => a.conditionalWagons.compareTo(b.conditionalWagons));
  return classes;
}

/// The smallest class this many wagons still fits inside, or null when the
/// train is longer than every class the handbook defines.
EchelonClass? classForWagonCount(int wagonCount, List<EchelonClass> classes) {
  for (final candidate in classes) {
    if (wagonCount <= candidate.conditionalWagons) return candidate;
  }
  return null;
}

/// Checks the train's length against the echelon classes.
///
/// A physical flatcar is one conditional wagon for counting purposes here;
/// the handbook's conversion table applies to passenger stock, which this app
/// does not model. That assumption is stated in the check's own wording rather
/// than left implicit, because it is the kind of simplification that would
/// otherwise quietly become a false pass.
ValidationCheck checkEchelonComposition({
  required int wagonCount,
  required List<EchelonClass> classes,
}) {
  if (classes.isEmpty || wagonCount <= 0) {
    return const ValidationCheck(
      ruleId: 'rule-echelon-class',
      label: AppStrings.echelonCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.echelonNoClassesDetail,
      referenceId: 'para-5',
    );
  }
  final matched = classForWagonCount(wagonCount, classes);
  if (matched == null) {
    final largest = classes.last;
    return ValidationCheck(
      ruleId: 'rule-echelon-class',
      label: AppStrings.echelonCheckLabel,
      status: CheckStatus.fail,
      detail: AppStrings.echelonTooLongDetail(wagonCount, largest.conditionalWagons),
      referenceId: largest.referenceId,
    );
  }
  return ValidationCheck(
    ruleId: 'rule-echelon-class',
    label: AppStrings.echelonCheckLabel,
    status: CheckStatus.pass,
    detail: AppStrings.echelonFitsDetail(
        wagonCount, matched.conditionalWagons, matched.maxTrainWeightT.round()),
    referenceId: matched.referenceId,
  );
}

/// Checks the load's overhang past the end of the wagon, which decides whether
/// a guard wagon has to be coupled in (plate-05, 400 mm).
///
/// [overhangMm] is only known when both the deck length and the vehicle length
/// are: it is what the load sticks out by once it is longer than the deck.
/// Null means the question cannot be answered yet, and the check says so.
ValidationCheck checkGuardWagon({
  required double? overhangMm,
  required Map<String, dynamic> rules,
}) {
  int? limit;
  String referenceId = 'plate-05';
  for (final entry in (rules['rules'] as List?) ?? const []) {
    final rule = entry as Map<String, dynamic>;
    if (rule['id'] != 'rule-overhang-guard-wagon') continue;
    final max = rule['maxOverhangMm'];
    if (max is num) limit = max.toInt();
    referenceId = (rule['referenceId'] as String?) ?? referenceId;
  }
  if (limit == null) {
    return const ValidationCheck(
      ruleId: 'rule-overhang-guard-wagon',
      label: AppStrings.guardWagonCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.guardWagonNoRuleDetail,
      referenceId: 'plate-05',
    );
  }
  if (overhangMm == null) {
    return ValidationCheck(
      ruleId: 'rule-overhang-guard-wagon',
      label: AppStrings.guardWagonCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.guardWagonUnknownDetail(limit),
      referenceId: referenceId,
    );
  }
  if (overhangMm > limit) {
    return ValidationCheck(
      ruleId: 'rule-overhang-guard-wagon',
      label: AppStrings.guardWagonCheckLabel,
      status: CheckStatus.fail,
      detail: AppStrings.guardWagonRequiredDetail(overhangMm.round(), limit),
      referenceId: referenceId,
    );
  }
  return ValidationCheck(
    ruleId: 'rule-overhang-guard-wagon',
    label: AppStrings.guardWagonCheckLabel,
    status: CheckStatus.pass,
    detail: AppStrings.guardWagonNotRequiredDetail(overhangMm.round(), limit),
    referenceId: referenceId,
  );
}
