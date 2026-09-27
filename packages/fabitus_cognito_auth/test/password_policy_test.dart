import 'package:fabitus_cognito_auth/fabitus_cognito_auth.dart';
import 'package:test/test.dart';

void main() {
  group('the default policy', () {
    const policy = PasswordPolicy();

    test("is Cognito's default: eight characters and every rule", () {
      expect(policy.minimumLength, 8);
      expect(policy.requirements, PasswordRequirement.values);
    });

    test('accepts a password meeting every rule', () {
      expect(policy.isSatisfiedBy('Secret1!'), isTrue);
    });

    test('names the rules a password breaks', () {
      expect(policy.unmet('secret'), [
        PasswordRequirement.minimumLength,
        PasswordRequirement.uppercase,
        PasswordRequirement.digit,
        PasswordRequirement.symbol,
      ]);
    });
  });

  group('a pool with twelve characters and no symbol rule', () {
    const policy = PasswordPolicy(minimumLength: 12, requireSymbol: false);

    test('lists only the rules it enforces', () {
      expect(policy.requirements, [
        PasswordRequirement.minimumLength,
        PasswordRequirement.uppercase,
        PasswordRequirement.lowercase,
        PasswordRequirement.digit,
      ]);
    });

    test('accepts a password without a symbol', () {
      expect(policy.isSatisfiedBy('Sicher123456'), isTrue);
    });

    test('rejects eleven characters and accepts twelve', () {
      expect(policy.isMet(PasswordRequirement.minimumLength, 'a' * 11), isFalse);
      expect(policy.isMet(PasswordRequirement.minimumLength, 'a' * 12), isTrue);
    });

    test('counts umlauts and symbols towards the length', () {
      expect(policy.isMet(PasswordRequirement.minimumLength, 'äöüÄÖÜ!?%&-_'), isTrue);
    });

    test('symbols pad the length but satisfy no letter or digit rule', () {
      expect(policy.isSatisfiedBy('Äö1!!!!!!!!!'), isTrue);
      expect(policy.isSatisfiedBy('!?%&-_!?%&-_'), isFalse);
    });

    test('rejects each missing rule', () {
      expect(policy.unmet('Kurz123'), [PasswordRequirement.minimumLength]);
      expect(policy.unmet('sicher123456'), [PasswordRequirement.uppercase]);
      expect(policy.unmet('SICHER123456'), [PasswordRequirement.lowercase]);
      expect(policy.unmet('SicheresWort'), [PasswordRequirement.digit]);
    });
  });

  group('each rule', () {
    const policy = PasswordPolicy();

    test('letters are matched Unicode aware', () {
      expect(policy.isMet(PasswordRequirement.uppercase, 'abcÄ'), isTrue);
      expect(policy.isMet(PasswordRequirement.lowercase, 'ABCä'), isTrue);
      expect(policy.isMet(PasswordRequirement.uppercase, 'abcä123!'), isFalse);
      expect(policy.isMet(PasswordRequirement.lowercase, 'ABCÄ123!'), isFalse);
    });

    test('digits are ASCII digits', () {
      expect(policy.isMet(PasswordRequirement.digit, 'abc1'), isTrue);
      expect(policy.isMet(PasswordRequirement.digit, 'abc٣'), isFalse);
    });

    test('symbols are the ones Cognito lists', () {
      for (final symbol in r'''^$*.[]{}()?"!@#%&/\,><':;|_~`=+-'''.split('')) {
        expect(policy.isMet(PasswordRequirement.symbol, 'abc$symbol'), isTrue, reason: symbol);
      }
      expect(policy.isMet(PasswordRequirement.symbol, 'abc§'), isFalse);
      expect(policy.isMet(PasswordRequirement.symbol, 'abc123'), isFalse);
    });

    test('an inner space counts as a symbol, a leading or trailing one does not', () {
      expect(policy.isMet(PasswordRequirement.symbol, 'ab cd'), isTrue);
      expect(policy.isMet(PasswordRequirement.symbol, ' abcd'), isFalse);
      expect(policy.isMet(PasswordRequirement.symbol, 'abcd '), isFalse);
    });
  });

  group('confirmationMatches', () {
    test('accepts identical values', () {
      expect(PasswordPolicy.confirmationMatches('Abc123', 'Abc123'), isTrue);
    });

    test('rejects differing values', () {
      expect(PasswordPolicy.confirmationMatches('Abc123', 'Abc124'), isFalse);
    });

    test('rejects an empty confirmation even for an empty password', () {
      expect(PasswordPolicy.confirmationMatches('', ''), isFalse);
    });
  });
}
