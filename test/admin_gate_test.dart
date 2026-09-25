import 'package:test/test.dart';

import 'package:railsim/presentation/widgets/common/trainee_dialog.dart';

void main() {
  test('only the exact admin name opens the panel', () {
    expect(isAdminName('admin', 'admin'), isTrue);
    expect(isAdminName('  Admin ', ' ADMIN '), isTrue, reason: 'case and spacing');
    expect(isAdminName('admin', 'adminn'), isFalse);
    expect(isAdminName('Nepes', 'Jorakulyyew'), isFalse);
    expect(isAdminName('', ''), isFalse);
  });
}
