import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../../data/models/attachment_type.dart';
import '../../data/models/vehicle.dart';
import '../models/securing_placement.dart';
import 'wood_chock_sizing.dart';

/// One concrete piece of securing hardware the trainee can put on the wagon,
/// at the size the handbook gives it.
///
/// Every entry is a row of a real table: a Table 3 weight bracket, one of the
/// eleven iron spurs, plate-02's side block. Nothing reaches this list without
/// a stated size, which is what lets the palette offer a piece at all — a
/// solid drawn to an invented dimension would be the most convincing wrong
/// object in the application, and the seating distance measured off it would
/// be a number about nothing.
class PlaceableHardware {
  final SecuringPieceKind kind;

  /// The row this came from, exactly as the table writes it — a weight
  /// bracket, a type code, a size. Shown beside the piece everywhere, so a
  /// figure can always be traced back to the line it was read off.
  final String typeCode;

  /// Height above the deck.
  final double heightM;

  /// Extent along the wagon. For a stop block this is the dimension the table
  /// calls its *width*.
  final double widthM;

  /// Extent across the wagon.
  final double lengthM;

  final String referenceId;

  /// True when this is the row the vehicle's own record resolves — the
  /// bracket its combat weight falls in, or the spur type its record names.
  final bool matchesVehicle;

  const PlaceableHardware({
    required this.kind,
    required this.typeCode,
    required this.heightM,
    required this.widthM,
    required this.lengthM,
    required this.referenceId,
    this.matchesVehicle = false,
  });

  /// Where to look for a picture of this piece.
  ///
  /// Not the same question as [referenceId], which is the paragraph or table
  /// the *size* was read off. A table can state a piece's dimensions while the
  /// figure that draws it sits under a different paragraph: the packing board
  /// is dimensioned in para. 24 and drawn in the method plates; the wire
  /// lashing's angle is table 7's and the lashing itself is figure 15.10 under
  /// para. 19. The paragraph this piece was sized from comes first, so the
  /// citation and the picture agree wherever they can, and the others follow.
  List<String> get figureReferenceIds => switch (kind) {
        SecuringPieceKind.woodPacking => const ['plate-02', 'plate-04', 'para-32'],
        SecuringPieceKind.wireLashing => const ['para-19', 'table-7'],
        _ => [referenceId],
      };
}

/// Everything [vehicle] can be secured with, sized from the handbook.
///
/// The list is deliberately not filtered down to what the vehicle's own record
/// resolves. The handbook's own catalogue screens already show every bracket
/// and every type so a trainee can compare the real alternatives; the row that
/// matches this vehicle is flagged rather than being the only one offered.
/// What *is* filtered is the wrong table: a tracked vehicle is never offered
/// the wheeled KGUUB variants, because those are sized by a different rule.
List<PlaceableHardware> placeableHardwareFor({
  required Vehicle vehicle,
  required Map<String, dynamic> measurements,
  required Map<String, dynamic> rules,
  List<AttachmentType> attachments = const [],
  double trackShoeWidthM = 0.58,
}) {
  final tracked = vehicle.category != VehicleCategory.wheeled;
  final out = <PlaceableHardware>[];

  // --- The squared wood stop block, one entry per weight bracket ----------
  final resolvedBracket = tracked && vehicle.bracketWeightT.isAvailable
      ? matchingWoodChockWeightRange(vehicle.bracketWeightT.asDouble!, measurements)
      : null;
  for (final row in _rows(measurements, chockTableKeyFor(vehicle.category))) {
    final bracket = (row['combatWeightRangeT'] ?? row['wheelDiameterRangeMm']) as String?;
    final h = _mm(row['chockHeightMm']);
    final w = _mm(row['chockWidthMm']);
    if (bracket == null || h == null || w == null) continue;
    out.add(PlaceableHardware(
      kind: SecuringPieceKind.woodChock,
      typeCode: tracked ? '$bracket t' : '$bracket mm',
      heightM: h,
      widthM: w,
      // plate-02: "the chock's length must not be less than the width of the
      // vehicle's track". The table sizes the cross-section and nothing else,
      // so the length follows the running gear it bears against.
      lengthM: math.max(trackShoeWidthM, trackShoeWidthM * 1.35),
      referenceId: tracked ? 'para-21' : 'plate-05',
      matchesVehicle: bracket == resolvedBracket,
    ));
  }

  // --- The half-round transverse insert -----------------------------------
  final insert = insertBlockDimensions(measurements);
  if (insert != null) {
    out.add(PlaceableHardware(
      kind: SecuringPieceKind.woodInsert,
      typeCode: insert.rangeLabel,
      heightM: insert.heightMm / 1000,
      widthM: insert.lengthMm / 1000,
      lengthM: trackShoeWidthM,
      referenceId: 'plate-02',
    ));
  }

  // --- plate-02's two lateral restraints ----------------------------------
  final arrangement = _rule(rules, 'rule-tracked-chock-arrangement');
  if (tracked && arrangement != null) {
    for (final entry in (arrangement['lateralRestraintOptions'] as List?) ?? const []) {
      final map = entry as Map<String, dynamic>;
      final blockSize = map['blockSizeMm'] as String?;
      if (blockSize != null) {
        final dims = _sizeTriple(blockSize);
        if (dims != null) {
          out.add(PlaceableHardware(
            kind: SecuringPieceKind.woodSideBlock,
            typeCode: '${blockSize.replaceAll('*', 'x')} mm',
            heightM: dims.$1,
            // The 2 m dimension runs along the wagon: the block is laid
            // *along* the inner and outer faces of the track.
            widthM: dims.$3,
            lengthM: dims.$2,
            referenceId: (arrangement['referenceId'] as String?) ?? 'plate-02',
          ));
        }
      }
      final stapleDia = _mm(map['minStapleDiameterMm']);
      if (stapleDia != null) {
        out.add(PlaceableHardware(
          kind: SecuringPieceKind.staple,
          // The bar's diameter is the only figure plate-02 gives for a
          // staple; how tall the bow stands and how far its legs are apart it
          // does not say. Those follow the diameter at a fixed proportion so
          // the thing can be drawn at all, and the label promises the
          // diameter and nothing else.
          typeCode: 'Ø${(stapleDia * 1000).round()} mm',
          heightM: stapleDia * 8,
          widthM: stapleDia,
          lengthM: stapleDia * 10,
          referenceId: (arrangement['referenceId'] as String?) ?? 'plate-02',
        ));
      }
    }
  }

  // --- The packing board ---------------------------------------------------
  final packing = attachments.where((a) => a.id == 'att-wood-packing').firstOrNull;
  final packingThickness = _packingThicknessM(packing);
  if (packingThickness != null) {
    out.add(PlaceableHardware(
      kind: SecuringPieceKind.woodPacking,
      // The only dimension the source fixes. A cross-board runs the width of
      // the wagon and its extent along the wagon is not stated anywhere, so
      // the label promises the thickness and nothing else.
      typeCode: '≥ ${(packingThickness * 1000).round()} mm',
      heightM: packingThickness,
      widthM: 0.30,
      lengthM: trackShoeWidthM * 1.6,
      referenceId: packing?.referenceId ?? 'para-24',
    ));
  }

  // --- The reusable KGUUB chock -------------------------------------------
  final kguubTable =
      tracked ? 'reusableChockTrackedTable' : 'reusableChockWheeledTable';
  for (final row in _rows(measurements, kguubTable)) {
    final plate = _sizeTriple((row['basePlateMm'] ?? row['setDimensionsMm']) as String?);
    final type = row['type'] as String?;
    if (plate == null || type == null) continue;
    out.add(PlaceableHardware(
      kind: SecuringPieceKind.ironChock,
      typeCode: type,
      // The plate thickness is stated; how far the stop stands above it is
      // not, so the drawn height is the plate plus a fixed rise recorded in
      // `securing_mesh_builder.dart`. Only the stated figures are labelled.
      heightM: plate.$3,
      widthM: plate.$1,
      lengthM: plate.$2,
      referenceId: 'para-29',
    ));
  }

  // --- Iron spurs and stop-boots ------------------------------------------
  for (final row in _rows(measurements, 'ironSpurTable')) {
    final plate = _sizeTriple(row['basePlateMm'] as String?);
    final type = row['type'] as String?;
    if (plate == null || type == null) continue;
    out.add(PlaceableHardware(
      kind: SecuringPieceKind.ironSpur,
      typeCode: type,
      heightM: plate.$3 + (_mm(row['combHeightMm']) ?? 0),
      // The long dimension runs across the wagon: a 580 mm base plate is the
      // width of a 580 mm track shoe, which is what it seats under.
      widthM: plate.$2,
      lengthM: plate.$1,
      referenceId: 'para-31',
      matchesVehicle: type == vehicle.ironSpurType,
    ));
  }
  for (final row in _rows(measurements, 'ironChockBootTable')) {
    final plate = _sizeTriple(row['basePlateMm'] as String?);
    final type = row['type'] as String?;
    if (plate == null || type == null) continue;
    final pin = _sizeTriple(row['pinMm'] as String?);
    out.add(PlaceableHardware(
      kind: SecuringPieceKind.ironChockBoot,
      typeCode: type,
      heightM: plate.$3 + (pin?.$1 ?? 0.02),
      widthM: plate.$2,
      lengthM: plate.$1,
      referenceId: 'para-32',
      matchesVehicle: type == vehicle.ironChockBootType,
    ));
  }

  // --- The wire lashing, one entry per diameter the stores carry ----------
  //
  // A wire has no shape to size, so the figures here are its diameter. What
  // decides a lashing is its strand count, and that comes from the vehicle's
  // weight (plate-03) or the installed angles (Table 7) — both of which the
  // view is given separately and states under the scene.
  final wire = attachments.where((a) => a.id == 'att-wire-lashing').firstOrNull;
  for (final dia in wire?.diametersAvailableMm ?? const <int>[]) {
    out.add(PlaceableHardware(
      kind: SecuringPieceKind.wireLashing,
      typeCode: 'Ø$dia mm',
      heightM: dia / 1000,
      widthM: dia / 1000,
      lengthM: dia / 1000,
      referenceId: wire?.referenceId ?? 'table-7',
    ));
  }

  return out;
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> measurements, String table) =>
    (((measurements[table] as Map<String, dynamic>?)?['rows'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

Map<String, dynamic>? _rule(Map<String, dynamic> rules, String id) {
  for (final entry in (rules['rules'] as List?) ?? const []) {
    final map = entry as Map<String, dynamic>;
    if (map['id'] == id) return map;
  }
  return null;
}

/// Millimetres from the table, in metres. Null for a cell that is not a plain
/// number — a range or an unreadable value produces no piece rather than a
/// piece of some default size.
double? _mm(Object? raw) => raw is num ? raw.toDouble() / 1000 : null;

/// `"280x200x8"` or `"100*100*2000"` as three lengths in metres.
(double, double, double)? _sizeTriple(String? raw) {
  if (raw == null) return null;
  final parts = raw.toLowerCase().split(RegExp(r'[x*×]'));
  if (parts.length != 3) return null;
  final values = <double>[];
  for (final part in parts) {
    final v = double.tryParse(part.trim());
    if (v == null) return null;
    values.add(v / 1000);
  }
  return (values[0], values[1], values[2]);
}

/// The packing board's minimum thickness, from its own attachment record.
double? _packingThicknessM(AttachmentType? packing) {
  if (packing == null) return null;
  final mm = packing.minThicknessMm;
  return mm == null ? null : mm / 1000;
}
