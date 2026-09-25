/// Who is sitting the attempt.
///
/// The trainer is used as a test: an instructor gets a result sheet back and
/// has to be able to tell whose it is. A sheet with no name on it is not much
/// use to anybody, which is why the name is asked for before the attempt
/// starts rather than offered as an optional field afterwards.
class Trainee {
  final String givenName;
  final String familyName;

  const Trainee({required this.givenName, required this.familyName});

  static const Trainee unknown = Trainee(givenName: '', familyName: '');

  /// Both halves given. An attempt cannot begin without this.
  bool get isComplete => givenName.trim().isNotEmpty && familyName.trim().isNotEmpty;

  /// Family name first, the way a register is written.
  String get displayName =>
      isComplete ? '${familyName.trim()} ${givenName.trim()}' : '';

  Trainee copyWith({String? givenName, String? familyName}) => Trainee(
        givenName: givenName ?? this.givenName,
        familyName: familyName ?? this.familyName,
      );

  @override
  bool operator ==(Object other) =>
      other is Trainee &&
      other.givenName == givenName &&
      other.familyName == familyName;

  @override
  int get hashCode => Object.hash(givenName, familyName);
}
