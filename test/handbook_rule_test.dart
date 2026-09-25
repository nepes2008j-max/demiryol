import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_rule.dart';

void main() {
  group('HandbookRule.fromRuleJson', () {
    test('parses a condition-based rule', () {
      final rule = HandbookRule.fromRuleJson({
        'id': 'rule-axle-load-wheeled-ramp',
        'appliesTo': 'wheeled',
        'description': 'Max axle load crossing flatcar side steel edges without ramps.',
        'condition': 'axleLoadT <= 10.0',
        'failMessage': 'Axle load exceeds 10 t.',
        'referenceId': 'para-51',
      });
      expect(rule.id, 'rule-axle-load-wheeled-ramp');
      expect(rule.appliesTo, 'wheeled');
      expect(rule.condition, 'axleLoadT <= 10.0');
      expect(rule.hasLookup, isFalse);
      expect(rule.isMethod, isFalse);
      expect(rule.displayTitle, rule.description);
    });

    test('flags a lookup-table rule via hasLookup', () {
      final rule = HandbookRule.fromRuleJson({
        'id': 'rule-wheeled-lashing-count',
        'description': 'Wire lashing count for method 2, by combat weight bracket.',
        'lookup': [
          {'combatWeightMaxT': 24.0, 'lashingsRequired': 4},
        ],
        'referenceId': 'para-55',
      });
      expect(rule.hasLookup, isTrue);
      expect(rule.condition, isNull);
    });
  });

  group('HandbookRule.fromMethodJson', () {
    test('parses an approved tracked-securing method', () {
      final rule = HandbookRule.fromMethodJson({
        'method': 2,
        'name': 'Iron spurs (Ş-series)',
        'referenceId': 'para-39',
      });
      expect(rule.id, 'method-2');
      expect(rule.isMethod, isTrue);
      expect(rule.methodNumber, 2);
      expect(rule.referenceId, 'para-39');
      expect(rule.displayTitle, '2-nji tassyklanan usul: Iron spurs (Ş-series)');
    });
  });
}
