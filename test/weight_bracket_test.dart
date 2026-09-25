import 'package:test/test.dart';
import 'package:railsim/domain/usecases/weight_bracket.dart';

void main() {
  group('weightMatchesRange', () {
    // Real brackets from measurements.json's trackChockByWeightTable (Table 3).
    test('"up to X" matches at and below the limit, not above', () {
      expect(weightMatchesRange(12.0, 'up to 12.0'), isTrue);
      expect(weightMatchesRange(11.9, 'up to 12.0'), isTrue);
      expect(weightMatchesRange(12.1, 'up to 12.0'), isFalse);
    });

    test('"min-max" matches inclusively within the range only', () {
      expect(weightMatchesRange(12.1, '12.1-18.0'), isTrue);
      expect(weightMatchesRange(18.0, '12.1-18.0'), isTrue);
      expect(weightMatchesRange(12.0, '12.1-18.0'), isFalse);
      expect(weightMatchesRange(18.1, '12.1-18.0'), isFalse);
    });

    test('"over X" matches strictly above the limit', () {
      expect(weightMatchesRange(18.1, 'over 18.0'), isTrue);
      expect(weightMatchesRange(18.0, 'over 18.0'), isFalse);
    });

    test('is case-insensitive and tolerates surrounding whitespace', () {
      expect(weightMatchesRange(5.0, '  UP TO 12.0  '), isTrue);
      expect(weightMatchesRange(20.0, '  OVER 18.0 '), isTrue);
    });

    test('unrecognized bracket text never matches (no silent guess)', () {
      expect(weightMatchesRange(10.0, 'roughly a lot'), isFalse);
      expect(weightMatchesRange(10.0, ''), isFalse);
    });
  });
}
