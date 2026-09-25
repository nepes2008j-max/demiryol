import 'package:test/test.dart';
import 'package:railsim/domain/usecases/wire_lashing_rule.dart';
import 'package:railsim/domain/usecases/wood_chock_sizing.dart';

void main() {
  group('resolveWoodChockDimensions', () {
    const measurements = {
      'trackChockByWeightTable': {
        'rows': [
          {'combatWeightRangeT': 'up to 12.0', 'chockHeightMm': 75, 'chockWidthMm': 150},
          {'combatWeightRangeT': '12.1-18.0', 'chockHeightMm': 100, 'chockWidthMm': 180},
          {'combatWeightRangeT': 'over 18.0', 'chockHeightMm': 180, 'chockWidthMm': 200},
        ],
      },
    };

    test('resolves the matching weight bracket exactly as Table 3 specifies', () {
      expect(resolveWoodChockDimensions(10.0, measurements), (heightMm: 75, widthMm: 150));
      expect(resolveWoodChockDimensions(15.0, measurements), (heightMm: 100, widthMm: 180));
      expect(resolveWoodChockDimensions(25.0, measurements), (heightMm: 180, widthMm: 200));
    });

    test('returns null rather than a guessed size when the table is absent', () {
      expect(resolveWoodChockDimensions(10.0, const {}), isNull);
    });
  });

  group('requiredWireLashingCount', () {
    const rules = {
      'rules': [
        {
          'id': 'rule-wheeled-lashing-count',
          'lookup': [
            {'combatWeightMaxT': 24.0, 'lashingsRequired': 4},
            {'combatWeightMaxT': 40.0, 'lashingsRequired': 8},
          ],
        },
      ],
    };

    test('reads the count straight from the rule\'s own weight brackets', () {
      expect(requiredWireLashingCount(20.0, rules), 4);
      expect(requiredWireLashingCount(24.0, rules), 4);
      expect(requiredWireLashingCount(30.0, rules), 8);
    });

    test('returns null (never a guessed count) outside every bracket or when the rule is missing', () {
      expect(requiredWireLashingCount(50.0, rules), isNull);
      expect(requiredWireLashingCount(20.0, const {}), isNull);
    });
  });
}
