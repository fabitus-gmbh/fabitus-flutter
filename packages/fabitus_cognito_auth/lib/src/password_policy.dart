/// One rule of a [PasswordPolicy].
///
/// The package does not word the rules - map each value to a label in your own
/// language, and render the checklist from [PasswordPolicy.requirements].
enum PasswordRequirement {
  /// At least [PasswordPolicy.minimumLength] characters.
  minimumLength,

  /// At least one uppercase letter.
  uppercase,

  /// At least one lowercase letter.
  lowercase,

  /// At least one digit.
  digit,

  /// At least one of the special characters Cognito accepts.
  symbol,
}

/// The client side mirror of a Cognito user pool's password policy.
///
/// Cognito is the authority - it rejects a password that breaks its policy
/// whatever the client says. The mirror exists for the live checklist under a
/// new password field, and to spare a round trip for a password that cannot
/// pass. Keep it in step with the user pool; when it drifts, Cognito's own
/// rejection still arrives as `AuthFailure.invalidPassword`.
///
/// The defaults are Cognito's defaults. A pool with twelve characters and no
/// symbol rule:
///
/// ```dart
/// const policy = PasswordPolicy(minimumLength: 12, requireSymbol: false);
///
/// for (final requirement in policy.requirements)
///   Checkbox(value: policy.isMet(requirement, password), ...);
/// ```
///
/// Letters are matched Unicode aware (`\p{Lu}`, `\p{Ll}`), so 'Ä' counts as
/// uppercase and 'ä' as lowercase. Digits are ASCII `0-9`. Symbols are the set
/// Cognito lists, plus a space that is neither leading nor trailing.
class PasswordPolicy {
  /// Creates a policy. Every rule is on by default, as in a new user pool.
  const PasswordPolicy({
    this.minimumLength = 8,
    this.requireUppercase = true,
    this.requireLowercase = true,
    this.requireDigit = true,
    this.requireSymbol = true,
  }) : assert(minimumLength >= 0, 'minimumLength must not be negative');

  /// The minimum number of characters. Cognito accepts 6 to 99; 8 is its
  /// default.
  final int minimumLength;

  /// Whether an uppercase letter is required.
  final bool requireUppercase;

  /// Whether a lowercase letter is required.
  final bool requireLowercase;

  /// Whether a digit is required.
  final bool requireDigit;

  /// Whether a special character is required.
  final bool requireSymbol;

  static final _uppercase = RegExp(r'\p{Lu}', unicode: true);
  static final _lowercase = RegExp(r'\p{Ll}', unicode: true);
  static final _digit = RegExp('[0-9]');
  static final _symbol = RegExp(r'''[\^$*.\[\]{}()?"!@#%&/\\,><':;|_~`=+\-]''');

  /// The rules this policy enforces, in checklist order.
  List<PasswordRequirement> get requirements => [
    PasswordRequirement.minimumLength,
    if (requireUppercase) PasswordRequirement.uppercase,
    if (requireLowercase) PasswordRequirement.lowercase,
    if (requireDigit) PasswordRequirement.digit,
    if (requireSymbol) PasswordRequirement.symbol,
  ];

  /// Whether [password] meets [requirement], whether or not this policy
  /// enforces it.
  bool isMet(PasswordRequirement requirement, String password) => switch (requirement) {
    PasswordRequirement.minimumLength => password.length >= minimumLength,
    PasswordRequirement.uppercase => _uppercase.hasMatch(password),
    PasswordRequirement.lowercase => _lowercase.hasMatch(password),
    PasswordRequirement.digit => _digit.hasMatch(password),
    PasswordRequirement.symbol => _symbol.hasMatch(password) || password.trim().contains(' '),
  };

  /// The rules [password] breaks, empty when it satisfies the policy.
  List<PasswordRequirement> unmet(String password) => [
    for (final requirement in requirements)
      if (!isMet(requirement, password)) requirement,
  ];

  /// Whether [password] meets every rule.
  bool isSatisfiedBy(String password) => unmet(password).isEmpty;

  /// Whether a confirmation field matches: identical and not empty.
  static bool confirmationMatches(String password, String confirmation) =>
      confirmation.isNotEmpty && password == confirmation;
}
