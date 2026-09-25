/// One selectable handbook-catalog entry for a required securing-hardware
/// slot — e.g. one row of Table 13 (iron spurs) or Table 11 (iron
/// chock-boots). Built by `equipment_catalog.dart` only from values already
/// present in `measurements.json`/`attachments.json`; a slot with no such
/// table produces no options rather than an invented one.
class EquipmentOption {
  final String hardwareId;
  final String typeCode;
  final Map<String, String> specs;
  final String referenceId;

  const EquipmentOption({
    required this.hardwareId,
    required this.typeCode,
    required this.specs,
    required this.referenceId,
  });
}
